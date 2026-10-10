require "test_helper"

# The backfill is plan-only, but its logic is real and must be right before
# anyone runs it on production. Tests run it against the test database, adding the
# status_legacy column and the CHECK constraint inside the test transaction
# (Postgres DDL is transactional), so nothing persists.
class StatusBackfillTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.add_column :assessments, :status_legacy, :text
    reset_columns
    @company = create_company
    @employee = create_employee(company: @company)
    @out = StringIO.new
  end

  teardown do
    reset_columns
  end

  def reset_columns
    @connection.schema_cache.clear!
    Assessment.reset_column_information
  end

  def backfill(**options)
    StatusBackfill.new(connection: @connection, pause: 0, out: @out, **options)
  end

  def legacy(status, **attrs)
    create_legacy_assessment(company: @company, employee: @employee, status: status, **attrs)
  end

  def stored(assessment)
    @connection.select_one("SELECT status, status_legacy FROM assessments WHERE id = #{assessment.id}")
  end

  # ---- mapping -------------------------------------------------------------

  test "the SQL mapping agrees with Status.classify for awkward values" do
    values = [
      "completed", "complete", "comp", "done", "pending", "in_progress", "needs_follow_up", "archived",
      "n/a", "nil", "null", "", nil, "  ", "Done", " DONE ", "ARCHIVED", "Completed\t", "\ncomp", "on hold",
      "in progress", "finished", "COMPLETE ", "N/A", "needs follow up", "x" * 200
    ]
    rows = values.map { |value| [ value, legacy(value) ] }

    backfill.run!

    rows.each do |raw, assessment|
      assert_equal Status.classify(raw), stored(assessment)["status"], "#{raw.inspect} should land in #{Status.classify(raw)}"
    end
  end

  test "the original value is kept, with a sentinel standing in for NULL" do
    done = legacy("done")
    nothing = legacy(nil)
    blank = legacy("")

    backfill.run!

    assert_equal({ "status" => "completed", "status_legacy" => "done" }, stored(done))
    assert_equal({ "status" => "pending", "status_legacy" => StatusBackfill::NULL_SENTINEL }, stored(nothing))
    assert_equal({ "status" => "pending", "status_legacy" => "" }, stored(blank))
  end

  test "rows that are already valid are not touched at all" do
    valid = legacy("completed")
    before = @connection.select_value("SELECT updated_at FROM assessments WHERE id = #{valid.id}")

    assert_equal 0, backfill.run!

    assert_equal({ "status" => "completed", "status_legacy" => nil }, stored(valid))
    assert_equal before, @connection.select_value("SELECT updated_at FROM assessments WHERE id = #{valid.id}")
  end

  test "updated_at is left alone on rows that are changed" do
    stamp = Time.utc(2025, 1, 2, 3, 4, 5)
    row = legacy("comp", created_at: stamp)

    backfill.run!

    assert_equal stamp, @connection.select_value("SELECT updated_at FROM assessments WHERE id = #{row.id}")
  end

  test "an unknown value is never guessed as completed" do
    assert_equal "needs_follow_up", stored(legacy("on hold").tap { backfill.run! })["status"]
  end

  # ---- running safely ------------------------------------------------------

  test "running again changes nothing" do
    3.times { legacy("comp") }

    assert_equal 3, backfill.run!
    assert_equal 0, backfill.run!
  end

  test "it works across batch boundaries and can be resumed from an id" do
    rows = Array.new(7) { legacy("done") }

    updated = backfill(batch_size: 2).run!

    assert_equal 7, updated
    assert(rows.all? { |row| stored(row)["status"] == "completed" })

    more = Array.new(4) { legacy("comp") }
    resumed = backfill(batch_size: 2).run!(from_id: more.last.id - 1)

    assert_equal 2, resumed
    assert_equal [ "completed", "completed" ], more.last(2).map { |row| stored(row)["status"] }
    assert_equal [ "comp", "comp" ], more.first(2).map { |row| stored(row)["status"] }
  end

  test "an empty table is a no-op" do
    Assessment.delete_all

    assert_nil backfill.run!
    assert_match(/nothing to do/, @out.string)
  end

  test "progress output contains numbers only, never row data" do
    legacy("on hold")
    legacy(nil)

    backfill.run!

    assert_no_match(/on hold|__null__|completed|pending/, @out.string)
  end

  test "it refuses to run before the status_legacy column exists" do
    @connection.remove_column :assessments, :status_legacy
    reset_columns

    error = assert_raises(StatusBackfill::NotReady) { backfill.run! }
    assert_match(/01_add_status_legacy/, error.message)
  end

  # ---- rollback ------------------------------------------------------------

  test "rollback restores the exact original values, NULL included" do
    originals = [ "done", nil, "", "on hold", "Comp ", "n/a" ]
    rows = originals.map { |value| legacy(value) }

    backfill.run!
    assert_equal originals.size, backfill.rollback!

    rows.zip(originals).each do |row, original|
      assert_equal({ "status" => original, "status_legacy" => nil }, stored(row))
    end
  end

  test "rollback does not undo an edit made after the backfill" do
    untouched = legacy("done")
    edited = legacy("comp")
    nulled = legacy(nil)
    backfill.run!

    # a person changes one backfilled row afterwards
    @connection.execute("UPDATE assessments SET status = 'archived' WHERE id = #{edited.id}")

    restored = backfill.rollback!

    assert_equal 2, restored
    assert_equal({ "status" => "done", "status_legacy" => nil }, stored(untouched))
    assert_equal({ "status" => nil, "status_legacy" => nil }, stored(nulled))
    assert_equal({ "status" => "archived", "status_legacy" => "comp" }, stored(edited), "the edit stays, and the original is kept for review")
    assert_match(/1 rows were edited after the backfill and were left exactly as they are/, @out.string)
  end

  test "rollback restores everything when nothing was edited, and says nothing about edits" do
    legacy("done")
    legacy("on hold")
    backfill.run!

    assert_equal 2, backfill.rollback!
    assert_no_match(/edited after the backfill/, @out.string)
    assert_equal 0, backfill.edited_since_backfill_count
  end

  test "a row edited back to the very value the backfill chose is restored, which is indistinguishable and harmless" do
    row = legacy("comp")
    backfill.run!
    @connection.execute("UPDATE assessments SET status = 'completed' WHERE id = #{row.id}")

    backfill.rollback!

    assert_equal({ "status" => "comp", "status_legacy" => nil }, stored(row))
  end

  test "rollback refuses while the CHECK constraint is in place" do
    legacy("done")
    backfill.run!
    @connection.execute(<<~SQL)
      ALTER TABLE assessments ADD CONSTRAINT status_allowed
      CHECK (status IS NOT NULL AND status IN ('pending', 'in_progress', 'completed', 'needs_follow_up', 'archived')) NOT VALID
    SQL

    error = assert_raises(StatusBackfill::NotReady) { backfill.rollback! }
    assert_match(/drop the status_allowed CHECK constraint first/, error.message)
  end

  test "the backfill works with the NOT VALID constraint in place, and it validates afterwards" do
    legacy("done")
    legacy(nil)
    @connection.execute(<<~SQL)
      ALTER TABLE assessments ADD CONSTRAINT status_allowed
      CHECK (status IS NOT NULL AND status IN ('pending', 'in_progress', 'completed', 'needs_follow_up', 'archived')) NOT VALID
    SQL

    backfill.run!

    assert_nothing_raised { @connection.execute("ALTER TABLE assessments VALIDATE CONSTRAINT status_allowed") }
  end

  test "validating fails while a bad row remains, which is the safety net" do
    legacy("done")
    @connection.execute(<<~SQL)
      ALTER TABLE assessments ADD CONSTRAINT status_allowed
      CHECK (status IS NOT NULL AND status IN ('pending', 'in_progress', 'completed', 'needs_follow_up', 'archived')) NOT VALID
    SQL

    assert_raises(ActiveRecord::StatementInvalid) { @connection.execute("ALTER TABLE assessments VALIDATE CONSTRAINT status_allowed") }
  end

  # ---- report --------------------------------------------------------------

  test "the report counts each value and where it would go, without writing" do
    [ "completed", "comp", "comp", "done", nil, "", "n/a", "on hold", "mystery", "mystery" ].each { |value| legacy(value) }
    legacy("", responses: { "q" => "answered" })

    result = backfill.report

    assert_equal 11, result.total
    assert_equal 1, result.already_valid
    assert_equal({ "mystery" => 2, "on hold" => 1 }, result.unknown)
    assert_equal 1, result.blank_with_responses
    assert_equal 0, @connection.select_value("SELECT COUNT(*) FROM assessments WHERE status_legacy IS NOT NULL")
  end

  test "the printed report lists unknown values for human review" do
    legacy("on hold")
    legacy("comp")

    backfill.print_report

    assert_match(/Unknown values/, @out.string)
    assert_match(/on hold/, @out.string)
    assert_match(/"comp"\s+-> completed/, @out.string)
  end
end
