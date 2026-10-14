require "test_helper"
require "csv"
require "minitest/mock"

class ExportsTest < ActionDispatch::IntegrationTest
  SECRET_EMAIL = "amara.private@example.com".freeze
  SECRET_TEXT = "lower back pain secret".freeze

  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @other_company = create_company(name: "Harbor & Pine Clinics")
    @other_admin = create_admin(company: @other_company, name: "Jonas Weber", email: "jonas@example.com")
    @amara = create_employee(company: @company, name: "Amara Okafor", email: SECRET_EMAIL)
    @theirs = create_employee(company: @other_company, name: "Zed Clinic", email: "zed@example.com", department: "Clinic")
  end

  def props
    inertia.props.with_indifferent_access
  end

  def completed(company: @company, employee: @amara, created_at: Time.utc(2026, 9, 10, 9), **rest)
    create_legacy_assessment(company: company, employee: employee, status: "completed", created_at: created_at, **rest)
  end

  def request_export(**params)
    post exports_path, params: params, headers: { "HTTP_REFERER" => assessments_url }
  end

  def downloaded_csv(export)
    get download_export_path(export)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    CSV.parse(response.body, headers: true)
  end

  test "everything requires sign in" do
    export = AssessmentExport.create!(company: @company, admin: @admin)

    get exports_path
    assert_redirected_to new_session_path
    get preview_exports_path
    assert_redirected_to new_session_path
    post exports_path
    assert_redirected_to new_session_path
    get download_export_path(export)
    assert_redirected_to new_session_path
    post retry_export_path(export)
    assert_redirected_to new_session_path
  end

  # ---- requesting -------------------------------------------------------

  test "an export is queued for the signed-in admin's own company" do
    completed
    sign_in_as(@admin)

    assert_enqueued_with(job: AssessmentExportJob) { request_export(status: "completed", from: "2026-09-01", to: "2026-09-30") }

    export = AssessmentExport.last
    assert_equal @company, export.company
    assert_equal @admin, export.admin
    assert_equal [ Date.new(2026, 9, 1), Date.new(2026, 9, 30), "completed", "queued" ], [ export.from_date, export.to_date, export.status_filter, export.state ]
    follow_redirect!
    assert_equal export.id, inertia.flash[:export_id]
  end

  test "a company id in the request can never choose the tenant" do
    completed
    completed(company: @other_company, employee: @theirs)
    sign_in_as(@admin)

    request_export(company_id: @other_company.id, company: { id: @other_company.id }, "export[company_id]" => @other_company.id)

    assert_equal @company, AssessmentExport.last.company
    assert_equal 0, @other_company.assessment_exports.count
  end

  test "only date range and status are read; every other parameter is ignored" do
    completed
    sign_in_as(@admin)

    request_export(status: "all", department: "Clinic", employee_email: SECRET_EMAIL, q: "x", columns: "employee_email", limit: 1, admin_id: @other_admin.id)

    export = AssessmentExport.last
    assert_equal @admin, export.admin
    assert_equal({ "from_date" => nil, "to_date" => nil, "status_filter" => "all" }, export.attributes.slice("from_date", "to_date", "status_filter"))
  end

  test "a dashboard search is not part of an export" do
    completed
    completed(employee: create_employee(company: @company, name: "Someone Else", email: "else@example.com"))
    sign_in_as(@admin)

    get preview_exports_path, params: { q: "amara", status: "all" }
    assert_equal 2, response.parsed_body["count"], "the preview counts what an export contains: the search is ignored"

    assert_difference -> { AssessmentExport.count }, 1 do
      request_export q: "amara", status: "all"
    end
    assert_equal({ from: nil, to: nil, status: "all" }, AssessmentExport.last.slice(:from_date, :to_date, :status_filter).symbolize_keys.transform_keys({ from_date: :from, to_date: :to, status_filter: :status }))
  end

  test "invalid requests create nothing and say why" do
    completed
    sign_in_as(@admin)

    {
      { from: "2026-10-05", to: "2026-10-01" } => /Start date is after end date/,
      { from: "13/45/2026" } => /Dates must look like/,
      { status: "comp" } => /Status filter is not included/,
      { status: "all", from: "2027-01-01", to: "2027-01-31" } => /No assessments match/
    }.each do |params, expected|
      assert_no_difference "AssessmentExport.count" do
        request_export(**params)
      end
      follow_redirect!
      assert_match expected, props[:errors][:export].to_sentence, params.inspect
    end
  end

  test "a fourth simultaneous export is refused" do
    completed
    sign_in_as(@admin)

    3.times { request_export }
    assert_equal 3, AssessmentExport.count

    assert_no_difference "AssessmentExport.count" do
      request_export
    end
    follow_redirect!
    assert_match(/already have 3 exports in progress/, props[:errors][:export].to_sentence)
  end

  # ---- preview ----------------------------------------------------------

  test "the preview counts exactly what an export would contain, legacy spellings included" do
    [ "completed", "comp", "done" ].each { |raw| create_legacy_assessment(company: @company, employee: @amara, status: raw) }
    create_legacy_assessment(company: @company, employee: @amara, status: "pending")
    create_legacy_assessment(company: @other_company, employee: @theirs, status: "completed")
    sign_in_as(@admin)

    get preview_exports_path, params: { status: "completed" }
    assert_equal 3, response.parsed_body["count"]

    get preview_exports_path
    assert_equal 4, response.parsed_body["count"], "the other company's row is not counted"
  end

  test "the preview reports problems instead of raising" do
    sign_in_as(@admin)

    get preview_exports_path, params: { from: "nonsense" }
    assert_equal 0, response.parsed_body["count"]
    assert_match(/Dates must look like/, response.parsed_body["error"])

    get preview_exports_path, params: { from: "2026-10-05", to: "2026-10-01" }
    assert_match(/Start date is after end date/, response.parsed_body["error"])
  end

  # ---- running the job --------------------------------------------------

  test "the job builds a redacted, correctly filtered file the admin can download" do
    completed(responses: { "free_text" => { "q7" => SECRET_TEXT } }.merge(sections_json(80, 70, 75, 75)))
    completed(created_at: Time.utc(2026, 8, 1, 9))
    completed(company: @other_company, employee: @theirs)
    sign_in_as(@admin)

    perform_enqueued_jobs { request_export(status: "completed", from: "2026-09-01", to: "2026-09-30") }

    export = AssessmentExport.last
    assert export.ready?
    assert_equal 1, export.row_count
    rows = downloaded_csv(export)
    assert_equal %w[assessment_id employee_ref department status score created_at], rows.headers
    assert_equal [ "completed", "75", "2026-09-10" ], rows.first.to_h.values_at("status", "score", "created_at")
    assert_not_includes response.body, SECRET_EMAIL
    assert_not_includes response.body, SECRET_TEXT
    assert_not_includes response.body, "Clinic"
  end

  test "running the same job twice builds the file once" do
    completed
    export = AssessmentExport.create!(company: @company, admin: @admin)

    AssessmentExportJob.perform_now(export.id)
    first_blob = export.reload.file.blob.id
    AssessmentExportJob.perform_now(export.id)

    assert_equal first_blob, export.reload.file.blob.id
    assert export.ready?
  end

  test "a failure is recorded generically and never logs the message" do
    completed
    export = AssessmentExport.create!(company: @company, admin: @admin)
    failing_builder = ->(*) { raise "boom: SELECT * FROM assessments WHERE employee_email = '#{SECRET_EMAIL}'" }

    log = captured_log do
      AssessmentExports::Builder.stub(:new, failing_builder) { AssessmentExportJob.perform_now(export.id) }
    end

    assert export.reload.failed?
    assert_equal "error", export.error_code
    assert_not_includes log, SECRET_EMAIL
    assert_not_includes log, "boom"
    assert_match(/assessment export #{export.id} failed: RuntimeError/, log)
  end

  test "an export that runs out of time fails with the timeout message" do
    5.times { completed }
    export = AssessmentExport.create!(company: @company, admin: @admin)

    AssessmentExports::Builder.stub(:max_seconds, -1) { AssessmentExportJob.perform_now(export.id) }

    assert export.reload.failed?
    assert_equal "timeout", export.error_code
    assert_match(/narrower date range/, export.error_message)
    assert_not export.file.attached?
  end

  test "job logs never carry arguments, filters or personal data" do
    completed(responses: { "free_text" => { "q7" => SECRET_TEXT } })
    export = AssessmentExport.create!(company: @company, admin: @admin)

    log = captured_log { AssessmentExportJob.perform_now(export.id) }

    assert_not_includes log, SECRET_EMAIL
    assert_not_includes log, SECRET_TEXT
    assert_no_match(/with arguments/, log)
  end

  # ---- downloading ------------------------------------------------------

  test "another company's download link just looks expired, and is not counted" do
    export = ready_export(company: @other_company, admin: @other_admin)
    sign_in_as(@admin)

    get download_export_path(export)

    assert_redirected_to exports_path
    assert_match(/expired/, flash[:alert])
    assert_equal 0, export.reload.download_count
  end

  test "someone else's export, an id that never existed and a really expired link all get the same answer" do
    theirs = ready_export(company: @other_company, admin: @other_admin)
    expired = ready_export.tap { |export| export.update_columns(expires_at: 1.minute.ago) }
    sign_in_as(@admin)

    answers = [ theirs.id, AssessmentExport.maximum(:id) + 1000, expired.id ].map do |id|
      get download_export_path(id)
      [ response.status, response.location, flash[:alert] ]
    end

    assert_equal 1, answers.uniq.size, "nothing may tell someone else's export from a missing one: #{answers.inspect}"
    assert_match(/expired/, answers.first.last)
  end

  test "another company's export cannot be retried" do
    export = ready_export(company: @other_company, admin: @other_admin)
    sign_in_as(@admin)

    post retry_export_path(export)

    assert_response :not_found
  end

  test "an export that is not ready cannot be downloaded" do
    export = AssessmentExport.create!(company: @company, admin: @admin)
    sign_in_as(@admin)

    get download_export_path(export)

    assert_redirected_to exports_path
    assert_match(/isn't ready/, flash[:alert])
  end

  test "an expired export cannot be downloaded" do
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)
    sign_in_as(@admin)
    export.update_columns(expires_at: 1.minute.ago)

    get download_export_path(export)

    assert_redirected_to exports_path
    assert_match(/expired/, flash[:alert])
  end

  test "the signed download link never reaches the logs" do
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)
    sign_in_as(@admin)

    log = captured_log { get download_export_path(export) }
    signed_path = URI(response.location).path

    assert_not_includes log, signed_path
    assert_no_match(%r{/rails/active_storage/disk/}, log)
    assert_match(/Redirected to \[FILTERED\]/, log)
  end

  test "the signed download link is short lived" do
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)
    sign_in_as(@admin)

    get download_export_path(export)
    link = response.location

    travel_to 2.minutes.from_now do
      get link
      assert_response :not_found
    end
  end

  test "expired files are purged" do
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)

    export.update_columns(expires_at: 1.minute.ago)

    PurgeExpiredExportsJob.perform_now

    assert_not export.reload.file.attached?
  end

  # ---- retry and the shared prop ----------------------------------------

  test "retry creates a new export with the same filters" do
    completed
    failed = AssessmentExport.create!(company: @company, admin: @admin, from_date: Date.new(2026, 9, 1), to_date: Date.new(2026, 9, 30), status_filter: "completed")
    failed.mark_failed!("timeout")
    sign_in_as(@admin)

    assert_enqueued_with(job: AssessmentExportJob) do
      post retry_export_path(failed), headers: { "HTTP_REFERER" => exports_url }
    end

    retried = AssessmentExport.where.not(id: failed.id).last
    assert_equal [ failed.from_date, failed.to_date, failed.status_filter, "queued" ], [ retried.from_date, retried.to_date, retried.status_filter, retried.state ]
  end

  test "the exports prop lists only this company's exports, newest first" do
    mine_old = AssessmentExport.create!(company: @company, admin: @admin, created_at: 30.minutes.ago)
    mine_new = AssessmentExport.create!(company: @company, admin: @admin)
    AssessmentExport.create!(company: @other_company, admin: @other_admin)
    sign_in_as(@admin)

    get exports_path

    assert_equal [ mine_new.id, mine_old.id ], props[:exports].map { |export| export[:id] }
    assert_equal [ "queued", "queued" ], props[:exports].map { |export| export[:state] }
    assert_nil props[:exports].first[:download_path]
  end

  test "the page is told the export columns and status options from one server-side definition" do
    sign_in_as(@admin)

    get exports_path

    assert_equal AssessmentExports::Builder::COLUMNS, props[:export_columns]
    assert_equal Status::CANONICAL, props[:status_options].map { |option| option[:value] }
    assert_equal "Needs follow-up", props[:status_options].find { |option| option[:value] == "needs_follow_up" }[:label]
  end

  test "a ready export exposes a download path, an expired one does not" do
    ready = AssessmentExport.create!(company: @company, admin: @admin)
    ready.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    ready.mark_ready!(row_count: 1)
    sign_in_as(@admin)

    get exports_path
    assert_equal download_export_path(ready), props[:exports].first[:download_path]

    ready.update_columns(expires_at: 1.minute.ago)

    get exports_path
    assert_nil props[:exports].first[:download_path]
    assert_equal "expired", props[:exports].first[:state]
  end

  # ---- audit trail: who exported, and how often it was fetched ----------------

  def ready_export(company: @company, admin: @admin)
    AssessmentExport.create!(company: company, admin: admin).tap do |export|
      export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
      export.mark_ready!(row_count: 1)
    end
  end

  test "every export says who requested it, and a colleague in the same company can see it" do
    colleague = create_admin(company: @company, name: "Daniel Osei", email: "daniel@example.com")
    AssessmentExport.create!(company: @company, admin: @admin)
    AssessmentExport.create!(company: @other_company, admin: @other_admin)
    sign_in_as(colleague)

    get exports_path

    assert_equal [ "Maya Reyes" ], props[:exports].map { |export| export[:requested_by] }
  end

  test "a retry is attributed to the admin who pressed Retry, not the original requester" do
    colleague = create_admin(company: @company, name: "Daniel Osei", email: "daniel@example.com")
    completed
    failed = AssessmentExport.create!(company: @company, admin: @admin)
    failed.mark_failed!("error")
    sign_in_as(colleague)

    post retry_export_path(failed), headers: { "HTTP_REFERER" => exports_url }

    assert_equal [ "Daniel Osei", "Maya Reyes" ], @company.assessment_exports.recent.map { |export| export.admin.name }
  end

  test "an export nobody has downloaded says so" do
    ready_export
    sign_in_as(@admin)

    get exports_path

    assert_equal 0, props[:exports].first[:download_count]
    assert_nil props[:exports].first[:last_downloaded_at]
  end

  test "each download is counted, and the time of the last one is kept" do
    export = ready_export
    sign_in_as(@admin)

    2.times do
      get download_export_path(export)
      assert_response :redirect
    end
    get exports_path

    assert_equal 2, export.reload.download_count
    assert_in_delta Time.current, export.last_downloaded_at, 5.seconds
    assert_equal 2, props[:exports].first[:download_count]
    assert_not_nil props[:exports].first[:last_downloaded_at]
  end

  test "a download that is refused is not counted" do
    not_ready = AssessmentExport.create!(company: @company, admin: @admin)
    expired = ready_export.tap { |export| export.update_columns(expires_at: 1.minute.ago) }
    theirs = ready_export(company: @other_company, admin: @other_admin)
    sign_in_as(@admin)

    get download_export_path(not_ready)
    get download_export_path(expired)
    get download_export_path(theirs)

    assert_equal [ 0, 0, 0 ], [ not_ready, expired, theirs ].map { |export| export.reload.download_count }
  end

  test "downloads clicked at the same moment are all counted, and the build heartbeat is untouched" do
    export = ready_export
    heartbeat = export.reload.updated_at

    AssessmentExport.find(export.id).record_download!
    AssessmentExport.find(export.id).record_download!

    assert_equal 2, export.reload.download_count
    assert_equal heartbeat, export.updated_at
  end

  # ---- exports whose worker died --------------------------------------------

  test "an export nobody is working on shows as failed with a Retry, not as building forever" do
    stuck = AssessmentExport.create!(company: @company, admin: @admin)
    stuck.update_columns(state: "processing", progress: 40, updated_at: 20.minutes.ago)
    sign_in_as(@admin)

    get exports_path

    view = props[:exports].find { |export| export[:id] == stuck.id }
    assert_equal "failed", view[:state]
    assert_equal "Failed", view[:state_label]
    assert_equal true, view[:can_retry]
    assert_match(/Something went wrong/, view[:error])
  end

  test "a stalled export can be retried" do
    completed
    stuck = AssessmentExport.create!(company: @company, admin: @admin)
    stuck.update_columns(state: "processing", updated_at: 20.minutes.ago)
    sign_in_as(@admin)

    assert_enqueued_with(job: AssessmentExportJob) do
      post retry_export_path(stuck), headers: { "HTTP_REFERER" => exports_url }
    end
  end

  test "a re-run after a crash takes over the dead claim and finishes the export" do
    completed
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.update_columns(state: "processing", progress: 55, updated_at: 20.minutes.ago)

    AssessmentExportJob.perform_now(export.id)

    assert export.reload.ready?
    assert_equal 1, export.row_count
  end

  test "a live claim is left alone" do
    completed
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.update_columns(state: "processing", progress: 55, updated_at: 1.minute.ago)

    AssessmentExportJob.perform_now(export.id)

    assert export.reload.processing?, "a worker that is still making progress must not be taken over"
    assert_not export.file.attached?
  end

  test "the reaper records dead exports as failed and leaves live ones" do
    dead_processing = AssessmentExport.create!(company: @company, admin: @admin).tap { |e| e.update_columns(state: "processing", updated_at: 20.minutes.ago) }
    dead_queued = AssessmentExport.create!(company: @company, admin: @admin).tap { |e| e.update_columns(created_at: 2.hours.ago) }
    live_processing = AssessmentExport.create!(company: @company, admin: @admin).tap { |e| e.update_columns(state: "processing", updated_at: 1.minute.ago) }
    live_queued = AssessmentExport.create!(company: @company, admin: @admin)

    ReapStuckExportsJob.perform_now

    assert dead_processing.reload.failed?
    assert dead_queued.reload.failed?
    assert_equal "error", dead_processing.error_code
    assert live_processing.reload.processing?
    assert live_queued.reload.queued?
  end

  test "dead exports do not count towards the cap, so they cannot lock a company out" do
    completed
    3.times { AssessmentExport.create!(company: @company, admin: @admin).update_columns(state: "processing", updated_at: 20.minutes.ago) }
    sign_in_as(@admin)

    assert_difference "AssessmentExport.count", 1 do
      request_export
    end
  end
end
