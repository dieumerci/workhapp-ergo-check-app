# PLAN ONLY. Designed and tested, but this repository never runs it against
# real data: see SOLUTION.md ("Release and rollback plan") for how and when it
# would be run, and `bin/rails status:backfill:report` for the read-only half.
#
# Brings historical assessments in line with the five standard statuses:
#
#   * report    read-only. How many rows hold each raw value and where each
#               would go, which unknown values need a human, and how many blank
#               statuses already carry answers.
#   * run!      updates in small batches by id range. Only rows that need it are
#               touched; the original value is copied to status_legacy first (a
#               sentinel stands in for NULL), so a row is never changed twice,
#               the run can be stopped and resumed, and every batch is valid on
#               its own. updated_at is left alone: this is not a user change.
#   * rollback! puts the original values back from status_legacy, but only for rows
#               still holding the value the backfill gave them: a status a person
#               changed afterwards is left alone and reported.
#
# The mapping is generated from Status (the same table the save path uses), so
# the SQL and the Ruby cannot drift apart; the tests check them against each other.
class StatusBackfill
  NULL_SENTINEL = "__null__".freeze
  # Ruby's String#strip whitespace, so SQL trimming matches Status.normalize.
  TRIM_CHARS = " \\t\\n\\r\\f\\v".freeze
  LOCK_TIMEOUT = "2s".freeze
  STATEMENT_TIMEOUT = "30s".freeze
  MAX_LOCK_RETRIES = 3

  class NotReady < StandardError; end

  Report = Struct.new(:total, :already_valid, :aliased, :blank, :unknown, :blank_with_responses, keyword_init: true)

  def initialize(connection: ActiveRecord::Base.connection, batch_size: 5_000, pause: 0.2, out: $stdout)
    @connection = connection
    @batch_size = Integer(batch_size)
    @pause = Float(pause)
    @out = out
  end

  # ---- read-only -----------------------------------------------------------

  def report
    counts = @connection.select_rows("SELECT status, COUNT(*) FROM assessments GROUP BY status").to_h { |raw, count| [ raw, count.to_i ] }
    already_valid = aliased = blank = 0
    alias_counts = Hash.new(0)
    unknown = {}

    counts.each do |raw, count|
      normalized = Status.normalize(raw)
      if normalized.nil?
        unknown[raw] = count
      elsif Status::CANONICAL.include?(raw)
        already_valid += count
      elsif blank_value?(raw)
        blank += count
        alias_counts[[ raw.inspect, normalized ]] += count
      else
        aliased += count
        alias_counts[[ raw.inspect, normalized ]] += count
      end
    end

    Report.new(
      total: counts.values.sum, already_valid: already_valid, aliased: alias_counts, blank: blank,
      unknown: unknown.sort_by { |_, count| -count }.to_h, blank_with_responses: blank_with_responses_count
    )
  end

  def print_report
    result = report
    @out.puts "Assessment status audit (read-only)"
    @out.puts "  rows in table                 #{result.total}"
    @out.puts "  already one of the five       #{result.already_valid}"
    @out.puts "  known aliases (will map)      #{result.aliased.sum { |_, count| count } - result.blank}"
    @out.puts "  blank / nil / n/a (-> pending) #{result.blank}"
    @out.puts "  unknown (-> needs_follow_up)  #{result.unknown.values.sum}"
    @out.puts "  blank AND already has answers #{result.blank_with_responses}  <- review before running"
    @out.puts
    @out.puts "Mapping that would be applied:"
    result.aliased.sort_by { |(raw, _), _| raw }.each { |(raw, target), count| @out.puts format("  %-22s -> %-16s %8d", raw, target, count) }
    return result if result.unknown.empty?

    @out.puts
    @out.puts "Unknown values (a human decides; they land in needs_follow_up, original kept in status_legacy):"
    result.unknown.each { |raw, count| @out.puts format("  %-42s %8d", raw.to_s.inspect[0, 42], count) }
    result
  end

  # ---- writes (guarded by the rake tasks) ---------------------------------

  def run!(from_id: nil)
    ensure_ready!
    first_id, last_id = id_bounds
    return say("nothing to do: the table is empty") if first_id.nil?

    from = [ from_id || first_id, first_id ].max
    updated = 0
    while from <= last_id
      to = from + @batch_size - 1
      updated += with_lock_retries { update_batch(from, to) }
      say("ids #{from}..#{[ to, last_id ].min}: #{updated} rows updated so far")
      from = to + 1
      sleep(@pause) if @pause.positive? && from <= last_id
    end
    updated
  end

  def rollback!
    ensure_ready!
    raise NotReady, "drop the status_allowed CHECK constraint first (it forbids the legacy values)" if check_constraint_present?

    first_id, last_id = id_bounds
    return say("nothing to do: the table is empty") if first_id.nil?

    restored = 0
    from = first_id
    while from <= last_id
      to = from + @batch_size - 1
      restored += with_lock_retries { restore_batch(from, to) }
      say("ids #{from}..#{[ to, last_id ].min}: #{restored} rows restored so far")
      from = to + 1
      sleep(@pause) if @pause.positive? && from <= last_id
    end

    left = edited_since_backfill_count
    say("#{left} rows were edited after the backfill and were left exactly as they are (status_legacy kept for review)") if left.positive?
    restored
  end

  # Rows still carrying status_legacy after a rollback: a person changed their
  # status after the backfill ran, so restoring the original would undo that edit.
  def edited_since_backfill_count
    ensure_ready!
    @connection.select_value("SELECT COUNT(*) FROM assessments WHERE status_legacy IS NOT NULL").to_i
  end

  # The SQL for one batch. Public so the release plan and the tests can show it.
  def update_sql(from, to)
    <<~SQL.squish
      UPDATE assessments
      SET status_legacy = COALESCE(status, #{quote(NULL_SENTINEL)}),
          status = #{target_sql}
      WHERE id BETWEEN #{Integer(from)} AND #{Integer(to)}
        AND status_legacy IS NULL
        AND (status IS NULL OR status NOT IN (#{Status::CANONICAL.map { |value| quote(value) }.join(', ')}))
    SQL
  end

  # The CASE that maps a raw status to its target. +column+ is the SQL expression
  # holding the raw value ("status" for the backfill; the legacy value when checking
  # whether a row is still as the backfill left it).
  def target_sql(column = "status")
    mapping = Status::CANONICAL.index_with(&:itself).merge(Status::ALIASES)
    whens = mapping.map { |raw, target| "WHEN #{quote(raw)} THEN #{quote(target)}" }
    "CASE lower(btrim(COALESCE(#{column}, ''), E'#{TRIM_CHARS}')) #{whens.join(' ')} ELSE #{quote(Status::UNKNOWN_TARGET)} END"
  end

  private

  def update_batch(from, to)
    in_short_transaction { @connection.exec_update(update_sql(from, to), "StatusBackfill") }
  end

  # Restores a row only if its status is still what the backfill set. If a person
  # has changed it since, their edit wins and the row is left (and reported).
  def restore_batch(from, to)
    original = "CASE WHEN status_legacy = #{quote(NULL_SENTINEL)} THEN NULL ELSE status_legacy END"
    sql = <<~SQL.squish
      UPDATE assessments
      SET status = #{original},
          status_legacy = NULL
      WHERE id BETWEEN #{Integer(from)} AND #{Integer(to)}
        AND status_legacy IS NOT NULL
        AND status = #{target_sql(original)}
    SQL
    in_short_transaction { @connection.exec_update(sql, "StatusBackfill") }
  end

  # Each batch is its own transaction with short timeouts, so it can never hold
  # locks for long or queue up behind (and block) application traffic.
  def in_short_transaction
    @connection.transaction(requires_new: true) do
      @connection.execute("SET LOCAL lock_timeout = '#{LOCK_TIMEOUT}'")
      @connection.execute("SET LOCAL statement_timeout = '#{STATEMENT_TIMEOUT}'")
      yield
    end
  end

  def with_lock_retries
    attempts = 0
    begin
      yield
    rescue ActiveRecord::LockWaitTimeout
      attempts += 1
      raise if attempts >= MAX_LOCK_RETRIES

      say("lock wait timed out, retrying (#{attempts}/#{MAX_LOCK_RETRIES})")
      sleep(@pause * attempts)
      retry
    end
  end

  def ensure_ready!
    return if @connection.column_exists?(:assessments, :status_legacy)

    raise NotReady, "assessments.status_legacy is missing. Run db/release_plan/01_add_status_legacy.sql first."
  end

  def check_constraint_present?
    @connection.select_value("SELECT 1 FROM pg_constraint WHERE conname = 'status_allowed' AND conrelid = 'assessments'::regclass").present?
  end

  def id_bounds
    row = @connection.select_one("SELECT MIN(id) AS first_id, MAX(id) AS last_id FROM assessments")
    [ row["first_id"], row["last_id"] ]
  end

  def blank_with_responses_count
    @connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM assessments
      WHERE (status IS NULL OR lower(btrim(status, E'#{TRIM_CHARS}')) IN ('', 'n/a', 'nil', 'null'))
        AND responses_json IS NOT NULL AND responses_json <> '{}'::jsonb AND responses_json <> 'null'::jsonb
    SQL
  end

  def blank_value?(raw)
    raw.nil? || Status::ALIASES[raw.to_s.strip.downcase] == Status::PENDING
  end

  def quote(value)
    @connection.quote(value)
  end

  def say(message)
    @out.puts(message)
  end
end
