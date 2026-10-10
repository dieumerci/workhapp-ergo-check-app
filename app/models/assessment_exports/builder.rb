require "csv"

module AssessmentExports
  # Builds the CSV for one export and attaches it.
  #
  # What leaves the system, and what does not:
  #   assessment_id  A-<id>
  #   employee_ref   one-way reference (EmployeeRef), never a name or e-mail
  #   department     as stored (guarded against spreadsheet formula injection)
  #   status         one of the five standard statuses, never a legacy spelling
  #   score          the rounded four-section average, blank when not scored
  #   created_at     date, YYYY-MM-DD
  # Free-text answers, raw responses, names and e-mail addresses are never read:
  # AssessmentRow.export_relation selects only what the columns above need, and a
  # test asserts the SQL never mentions them.
  #
  # Rows are read in batches of 1,000 so memory stays flat however large the
  # company is, written to a temp file, then attached. Progress is saved after
  # each batch so the UI can show a real bar.
  class Builder
    COLUMNS = %w[assessment_id employee_ref department status score created_at].freeze
    BATCH_SIZE = 1_000
    ROW_SEPARATOR = "\r\n".freeze
    FORMULA_PREFIX = /\A[=+\-@\t\r]/

    def self.max_seconds
      Integer(ENV.fetch("EXPORT_MAX_SECONDS", 300))
    end

    def initialize(export, max_seconds: self.class.max_seconds, batch_size: BATCH_SIZE)
      @export = export
      @max_seconds = max_seconds
      @batch_size = batch_size
    end

    def call
      relation = Scope.call(@export.company, from: @export.from_date, to: @export.to_date, status: @export.status_filter)
      total = relation.count
      started = monotonic_now
      rows = 0

      Tempfile.create([ "assessments-export", ".csv" ]) do |file|
        file.write(CSV.generate_line(COLUMNS, row_sep: ROW_SEPARATOR))

        AssessmentRow.export_relation(relation).find_in_batches(batch_size: @batch_size) do |batch|
          raise TimeBudgetExceeded if monotonic_now - started > @max_seconds

          batch.each do |record|
            file.write(CSV.generate_line(fields(AssessmentRow.build(record)), row_sep: ROW_SEPARATOR))
          end
          rows += batch.size
          @export.update_columns(progress: [ rows * 100 / [ total, 1 ].max, 99 ].min, updated_at: Time.current)
        end

        file.flush
        file.rewind
        @export.file.attach(io: file, filename: filename, content_type: "text/csv")
      end

      @export.mark_ready!(row_count: rows)
    end

    private

    def fields(row)
      [ row.code, row.employee_ref, safe(row.department), row.status, row.score, row.created_on ]
    end

    # A cell that starts with = + - @ (or a tab/CR) is run as a formula by
    # spreadsheet software. Prefix it with an apostrophe so it stays text.
    def safe(value)
      return if value.nil? # an empty cell, not a quoted empty string

      text = value.to_s
      text.match?(FORMULA_PREFIX) ? "'#{text}" : text
    end

    def filename
      "assessments-#{@export.created_at.to_date.iso8601}-#{@export.id}.csv"
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
