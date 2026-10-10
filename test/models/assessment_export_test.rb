require "test_helper"

class AssessmentExportTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @admin = create_admin(company: @company)
  end

  def export(**attrs)
    AssessmentExport.create!({ company: @company, admin: @admin }.merge(attrs))
  end

  test "starts queued with no progress" do
    record = export

    assert record.queued?
    assert_equal 0, record.progress
    assert_equal "all", record.status_filter
  end

  test "only the five statuses or all can be a filter" do
    assert_not AssessmentExport.new(company: @company, admin: @admin, status_filter: "comp").valid?
    assert_not AssessmentExport.new(company: @company, admin: @admin, status_filter: "").valid?
    (Status::CANONICAL + [ "all" ]).each do |value|
      assert AssessmentExport.new(company: @company, admin: @admin, status_filter: value).valid?, value
    end
  end

  test "a backwards range is invalid" do
    record = AssessmentExport.new(company: @company, admin: @admin, from_date: Date.new(2026, 10, 5), to_date: Date.new(2026, 10, 1))

    assert_not record.valid?
    assert_includes record.errors.full_messages, "Start date is after end date"
  end

  test "a company can only have three exports in progress" do
    3.times { export }
    fourth = AssessmentExport.new(company: @company, admin: @admin)

    assert_not fourth.valid?
    assert_match(/already have 3 exports in progress/, fourth.errors.full_messages.first)

    other = create_company(name: "Harbor & Pine Clinics")
    assert AssessmentExport.new(company: other, admin: create_admin(company: other, email: "j@example.com")).valid?, "the cap is per company"
  end

  test "finished exports do not count towards the cap" do
    3.times { export.mark_failed!("error") }

    assert AssessmentExport.new(company: @company, admin: @admin).valid?
  end

  test "claim! lets exactly one caller run the job" do
    record = export

    assert record.claim!
    assert record.processing?
    assert_not AssessmentExport.find(record.id).claim!
  end

  test "ready exports are downloadable for 24 hours, then expire" do
    record = export
    record.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    record.mark_ready!(row_count: 1)

    assert record.downloadable?
    assert_in_delta 24.hours.from_now.to_i, record.expires_at.to_i, 5

    travel_to 25.hours.from_now do
      assert record.expired?
      assert_not record.downloadable?
      assert_equal "expired", record.display_state
      assert record.to_view[:can_retry]
    end
  end

  test "failures are shown as generic messages" do
    record = export
    record.mark_failed!("timeout")

    assert_match(/narrower date range/, record.to_view[:error])
    assert record.to_view[:can_retry]
    assert_nil export.to_view[:error]
  end

  test "the view carries no personal data" do
    view = export(from_date: Date.new(2026, 9, 1), to_date: Date.new(2026, 9, 30), status_filter: "completed").to_view

    assert_equal %i[can_retry error from id progress requested_at row_count state state_label status status_label to], view.keys.sort
    assert_equal "Completed", view[:status_label]
  end

  test "stalled means no heartbeat for a while, not merely slow" do
    processing = export
    processing.claim!

    assert_not processing.stalled?
    processing.update_columns(updated_at: 11.minutes.ago)
    assert processing.stalled?
    assert_equal "failed", processing.display_state
    assert_not processing.active?
  end

  test "claim! takes over only a silent processing export" do
    record = export
    assert record.claim!

    fresh = AssessmentExport.find(record.id)
    assert_not fresh.claim!, "a live worker keeps its claim"

    record.update_columns(updated_at: 11.minutes.ago)
    assert AssessmentExport.find(record.id).claim!, "a dead worker's claim can be taken"
  end

  test "in_flight excludes dead exports and the stalled scope finds them" do
    alive = export
    dead = export
    dead.update_columns(state: "processing", updated_at: 20.minutes.ago)

    assert_equal [ alive.id ], AssessmentExport.in_flight.pluck(:id)
    assert_equal [ dead.id ], AssessmentExport.stalled.pluck(:id)
  end
end
