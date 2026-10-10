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

  test "another company's export cannot be downloaded or retried" do
    export = AssessmentExport.create!(company: @other_company, admin: @other_admin)
    export.file.attach(io: StringIO.new("secret\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)
    sign_in_as(@admin)

    get download_export_path(export)
    assert_response :not_found

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
    mine_old = AssessmentExport.create!(company: @company, admin: @admin, created_at: 2.days.ago)
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
end
