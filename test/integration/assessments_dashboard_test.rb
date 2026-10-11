require "test_helper"

class AssessmentsDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @other_company = create_company(name: "Harbor & Pine Clinics")
    @other_admin = create_admin(company: @other_company, name: "Jonas Weber", email: "jonas@example.com")
  end

  def props
    inertia.props.with_indifferent_access
  end

  def visit(**query)
    get assessments_path, params: query
    assert_response :success
  end

  def rows
    props[:assessments]
  end

  # ---- tenancy -----------------------------------------------------------

  test "only the signed-in admin's company is listed or counted" do
    mine = create_legacy_assessment(company: @company, status: "completed")
    theirs = create_legacy_assessment(company: @other_company, status: "completed")
    sign_in_as(@admin)

    visit

    assert_equal [ mine.id ], rows.map { |row| row[:id] }
    assert_not_includes rows.map { |row| row[:id] }, theirs.id
    assert_equal 1, props[:counts][:all]
    assert_equal 1, props[:counts][:completed]
  end

  test "a company_id in the request cannot widen or change the tenant" do
    create_legacy_assessment(company: @company, status: "completed")
    theirs = create_legacy_assessment(company: @other_company, status: "completed")
    sign_in_as(@admin)

    visit company_id: @other_company.id, "company[id]" => @other_company.id

    assert_not_includes rows.map { |row| row[:id] }, theirs.id
    assert_equal 1, props[:counts][:all]
  end

  test "another company's assessment cannot be opened in the drawer" do
    theirs = create_legacy_assessment(company: @other_company, status: "completed")
    sign_in_as(@admin)

    visit selected: theirs.id

    assert_nil props[:selected]
  end

  test "another company's assessment cannot be updated" do
    theirs = create_assessment(company: @other_company, status: "pending")
    sign_in_as(@admin)

    patch assessment_path(theirs), params: { status: "archived" }

    assert_response :not_found
    assert_equal "pending", theirs.reload.status
  end

  test "the dashboard requires sign in" do
    get assessments_path
    assert_redirected_to new_session_path

    patch assessment_path(create_assessment(company: @company)), params: { status: "archived" }
    assert_redirected_to new_session_path
  end

  # ---- status counts and filter on messy legacy data --------------------

  test "legacy spellings are folded into the five statuses for counts and filter" do
    [ "completed", "comp", "done", "complete", "Completed " ].each { |raw| create_legacy_assessment(company: @company, status: raw) }
    [ "pending", nil, "", "n/a" ].each { |raw| create_legacy_assessment(company: @company, status: raw) }
    create_legacy_assessment(company: @company, status: "in_progress")
    create_legacy_assessment(company: @company, status: "on hold")
    create_legacy_assessment(company: @company, status: "needs_follow_up")
    create_legacy_assessment(company: @company, status: "archived")
    sign_in_as(@admin)

    visit

    assert_equal({ "all" => 13, "pending" => 4, "in_progress" => 1, "completed" => 5, "needs_follow_up" => 2, "archived" => 1 }, props[:counts].to_h)

    visit status: "completed"
    assert_equal 5, props[:pagination][:total]
    assert_equal [ "completed" ], rows.map { |row| row[:status] }.uniq

    visit status: "pending"
    assert_equal 4, rows.size

    visit status: "needs_follow_up"
    assert_equal 2, rows.size, "an unknown legacy status shows up under needs follow-up, not nowhere"
  end

  # ---- search --------------------------------------------------------------

  def search_fixtures
    @priya = create_employee(company: @company, name: "Priya Carter", department: "Finance", email: "priya@example.com")
    @tariq = create_employee(company: @company, name: "Tariq Rossi", department: "Warehouse", email: "tariq@example.com")
    @priya_done = create_legacy_assessment(company: @company, employee: @priya, status: "comp", created_at: 3.days.ago)
    @priya_open = create_legacy_assessment(company: @company, employee: @priya, status: "pending", created_at: 2.days.ago)
    @tariq_done = create_legacy_assessment(company: @company, employee: @tariq, status: "completed", created_at: 1.day.ago)
  end

  test "searching by name lists that employee's assessments, newest first" do
    search_fixtures
    sign_in_as(@admin)

    visit q: "priya"

    assert_equal [ @priya_open.id, @priya_done.id ], rows.map { |row| row[:id] }
    assert_equal "priya", props[:filters][:q]
    assert_equal 2, props[:pagination][:total]
  end

  test "the chip counts and the legacy note describe the search, not the whole company" do
    search_fixtures
    sign_in_as(@admin)

    visit q: "priya"

    assert_equal({ "all" => 2, "pending" => 1, "in_progress" => 0, "completed" => 1, "needs_follow_up" => 0, "archived" => 0 }, props[:counts].to_h)
    assert_equal 1, props[:legacy][:aliases], "only the searched rows are described"
  end

  test "search combines with the status filter and the date range" do
    search_fixtures
    sign_in_as(@admin)

    visit q: "priya", status: "completed"
    assert_equal [ @priya_done.id ], rows.map { |row| row[:id] }

    visit q: "priya", preset: "7"
    assert_equal 2, rows.size
    visit q: "priya", from: 1.day.ago.to_date.iso8601
    assert_empty rows
  end

  test "searching by department and by code works, and a miss is an honest empty page" do
    search_fixtures
    sign_in_as(@admin)

    visit q: "warehouse"
    assert_equal [ @tariq_done.id ], rows.map { |row| row[:id] }

    visit q: "A-#{@priya_done.id}"
    assert_equal [ @priya_done.id ], rows.map { |row| row[:id] }

    visit q: "nobody by this name"
    assert_empty rows
    assert_equal 1, props[:pagination][:pages]
    assert_equal 0, props[:counts][:all]
  end

  test "a search never reaches another company's employees or assessments" do
    search_fixtures
    theirs = create_employee(company: @other_company, name: "Priya Carter", department: "Clinic", email: "p@example.com")
    other = create_legacy_assessment(company: @other_company, employee: theirs, status: "completed")
    sign_in_as(@admin)

    visit q: "priya"
    assert_not_includes rows.map { |row| row[:id] }, other.id

    visit q: other.id.to_s
    assert_empty rows, "another company's assessment code finds nothing"
  end

  test "a search still costs two assessment queries" do
    search_fixtures
    sign_in_as(@admin)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%("assessments")) && payload[:name] != "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { visit q: "priya carter" }

    assert_equal 2, queries.size, "expected one grouped count and one page query, got:\n#{queries.join("\n")}"
  end

  test "odd input is harmless: wildcards, long text, arrays and hashes" do
    search_fixtures
    sign_in_as(@admin)

    visit q: "%"
    assert_empty rows
    visit q: "x" * 5_000
    assert_equal AssessmentSearch::MAX_LENGTH, props[:filters][:q].length
    get assessments_path, params: { q: [ "priya" ] }
    assert_response :success
    assert_equal "", props[:filters][:q]
    get assessments_path, params: { q: { a: "b" } }
    assert_response :success
  end

  test "the search is never remembered, not even with consent" do
    search_fixtures
    sign_in_as(@admin)
    post cookie_consent_path, params: { preferences: "true" }

    visit q: "priya", status: "all", preset: "all"
    get assessments_path

    assert_equal "", props[:filters][:q]
    assert_not_includes response.headers["Set-Cookie"].to_s, "priya"
    assert_not_includes cookies.to_hash.values.join(" "), "priya"
  end

  test "a search on its own does not discard the remembered status and range" do
    search_fixtures
    sign_in_as(@admin)
    post cookie_consent_path, params: { preferences: "true" }
    visit status: "completed", preset: "all"

    visit q: "priya"

    assert_equal "completed", props[:filters][:status]
    assert_equal "priya", props[:filters][:q]
    assert_equal [ @priya_done.id ], rows.map { |row| row[:id] }
  end

  test "searches are rate limited, politely" do
    search_fixtures
    sign_in_as(@admin)

    180.times { get assessments_path, params: { q: "priya" } }
    get assessments_path, params: { q: "priya" }

    assert_redirected_to assessments_path
    assert_match(/Too many searches/, flash[:alert])
    get assessments_path
    assert_response :success, "plain browsing is not limited by searching"
  end

  # ---- the data-tidiness note ---------------------------------------------

  test "a company with legacy statuses is told how many, and which spellings, without an extra query" do
    [ "completed", "pending", "in_progress" ].each { |raw| create_legacy_assessment(company: @company, status: raw) }
    [ "comp", "comp", "done", "Complete " ].each { |raw| create_legacy_assessment(company: @company, status: raw) }
    [ nil, "", "n/a" ].each { |raw| create_legacy_assessment(company: @company, status: raw) }
    create_legacy_assessment(company: @company, status: "on hold")
    sign_in_as(@admin)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%("assessments")) && payload[:name] != "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { visit }

    legacy = props[:legacy]
    assert_equal({ "records" => 8, "standard" => 3, "aliases" => 4, "blank" => 3, "unknown" => 1 }, legacy.slice(:records, :standard, :aliases, :blank, :unknown).to_h)
    assert_equal %w[comp complete done], legacy[:spellings], "most common first, then alphabetical; case and spaces folded"
    assert_equal 2, queries.size, "the note must come from the counts the page already fetches"
  end

  test "a company whose statuses are all standard gets no note" do
    %w[completed pending archived].each { |raw| create_legacy_assessment(company: @other_company, status: raw) }
    create_legacy_assessment(company: @company, status: "comp")
    sign_in_as(@other_admin)

    visit

    assert_nil props[:legacy]
  end

  test "an unrecognised value is counted but never shown" do
    create_legacy_assessment(company: @company, status: "SECRET diagnosis: lower back")
    sign_in_as(@admin)

    visit

    assert_equal 1, props[:legacy][:unknown]
    assert_empty props[:legacy][:spellings]
    assert_not_includes inertia.props.to_json, "SECRET diagnosis"
  end

  test "the note counts only this company and follows the date range" do
    create_legacy_assessment(company: @company, status: "done", created_at: 200.days.ago)
    create_legacy_assessment(company: @company, status: "completed", created_at: 2.days.ago)
    create_legacy_assessment(company: @other_company, status: "comp", created_at: 2.days.ago)
    sign_in_as(@admin)

    visit
    assert_equal 1, props[:legacy][:records]

    visit preset: "30"
    assert_nil props[:legacy], "the only legacy row is older than 30 days"
  end

  test "the note is not computed when only the drawer is opened" do
    assessment = create_legacy_assessment(company: @company, status: "comp")
    sign_in_as(@admin)

    get assessments_path, params: { selected: assessment.id }, headers: partial_headers("selected")

    assert_nil props[:legacy]
    assert_equal assessment.id, props[:selected][:id]
  end

  test "an unknown status value in the URL means no status filter" do
    create_legacy_assessment(company: @company, status: "completed")
    sign_in_as(@admin)

    visit status: "bogus'; DROP TABLE assessments;--"

    assert_equal "all", props[:filters][:status]
    assert_equal 1, rows.size
  end

  # ---- dates --------------------------------------------------------------

  test "from and to are inclusive of the whole day" do
    travel_to Time.utc(2026, 10, 10, 12) do
      early = create_legacy_assessment(company: @company, status: "completed", created_at: Time.utc(2026, 10, 1, 0, 0, 1))
      late = create_legacy_assessment(company: @company, status: "completed", created_at: Time.utc(2026, 10, 5, 23, 59, 59))
      outside_before = create_legacy_assessment(company: @company, status: "completed", created_at: Time.utc(2026, 9, 30, 23, 59, 59))
      outside_after = create_legacy_assessment(company: @company, status: "completed", created_at: Time.utc(2026, 10, 6, 0, 0, 1))
      sign_in_as(@admin)

      visit from: "2026-10-01", to: "2026-10-05"

      assert_equal [ early.id, late.id ].sort, rows.map { |row| row[:id] }.sort
      assert_not_includes rows.map { |row| row[:id] }, outside_before.id
      assert_not_includes rows.map { |row| row[:id] }, outside_after.id
      assert_equal "custom", props[:filters][:preset]
    end
  end

  test "presets compute their own dates relative to today" do
    travel_to Time.utc(2026, 10, 10, 12) do
      recent = create_legacy_assessment(company: @company, status: "completed", created_at: 3.days.ago)
      create_legacy_assessment(company: @company, status: "completed", created_at: 40.days.ago)
      sign_in_as(@admin)

      visit preset: "7"

      assert_equal [ recent.id ], rows.map { |row| row[:id] }
      assert_equal({ "preset" => "7", "from" => "2026-10-03", "to" => "2026-10-10" }, props[:filters].slice(:preset, :from, :to).to_h)
    end
  end

  test "chip counts follow the date range but not the status filter" do
    travel_to Time.utc(2026, 10, 10, 12) do
      create_legacy_assessment(company: @company, status: "completed", created_at: 2.days.ago)
      create_legacy_assessment(company: @company, status: "pending", created_at: 2.days.ago)
      create_legacy_assessment(company: @company, status: "pending", created_at: 60.days.ago)
      sign_in_as(@admin)

      visit preset: "7", status: "completed"

      assert_equal 1, rows.size
      assert_equal 1, props[:counts][:pending]
      assert_equal 2, props[:counts][:all]
    end
  end

  test "malformed dates are ignored rather than raising" do
    create_legacy_assessment(company: @company, status: "completed")
    sign_in_as(@admin)

    visit from: "not-a-date", to: "2026-13-45"

    assert_equal "all", props[:filters][:preset]
    assert_equal 1, rows.size
  end

  test "a backwards range simply matches nothing" do
    create_legacy_assessment(company: @company, status: "completed")
    sign_in_as(@admin)

    visit from: "2026-10-05", to: "2026-10-01"

    assert_empty rows
    assert_equal 0, props[:pagination][:total]
  end

  # ---- pagination ---------------------------------------------------------

  test "pages hold ten rows, newest first, and out-of-range pages are clamped" do
    created = Array.new(25) { |index| create_legacy_assessment(company: @company, status: "completed", created_at: (25 - index).hours.ago) }
    sign_in_as(@admin)

    visit
    assert_equal 10, rows.size
    assert_equal({ "page" => 1, "pages" => 3, "total" => 25, "per_page" => 10 }, props[:pagination].to_h)
    assert_equal created.last(10).map(&:id).reverse, rows.map { |row| row[:id] }, "newest first"

    visit page: 3
    assert_equal 5, rows.size

    visit page: 99
    assert_equal 3, props[:pagination][:page]

    visit page: "-4"
    assert_equal 1, props[:pagination][:page]
  end

  test "an empty result still reports one page" do
    sign_in_as(@admin)

    visit

    assert_empty rows
    assert_equal({ "page" => 1, "pages" => 1, "total" => 0, "per_page" => 10 }, props[:pagination].to_h)
  end

  # ---- what the page may contain -----------------------------------------

  test "rows never carry e-mail addresses, free text or raw responses" do
    employee = create_employee(company: @company, name: "Amara Okafor", email: "amara.private@example.com")
    create_legacy_assessment(
      company: @company, status: "completed", employee: employee,
      responses: { "free_text" => { "q7" => "lower back pain secret" } }.merge(sections_json(80, 70, 75, 75))
    )
    sign_in_as(@admin)

    visit
    body = response.body

    assert_not_includes body, "amara.private@example.com"
    assert_not_includes body, "lower back pain secret"
    assert_no_match(/responses_json|employee_email|free_text/, body)
    assert_equal "Amara Okafor", rows.first[:employee_name]
    assert_match(/\Aemp_[0-9a-f]{12}\z/, rows.first[:employee_ref])
  end

  test "the page uses two assessment queries however many rows there are" do
    12.times { create_legacy_assessment(company: @company, status: "completed", responses: sections_json(80, 70, 75, 75)) }
    sign_in_as(@admin)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%("assessments")) && payload[:name] != "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { visit }

    assert_equal 2, queries.size, "expected one grouped count and one page query, got:\n#{queries.join("\n")}"
  end

  test "opening the drawer does no dashboard work" do
    assessment = create_legacy_assessment(company: @company, status: "completed", responses: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%("assessments")) && payload[:name] != "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get assessments_path, params: { selected: assessment.id }, headers: partial_headers("selected")
    end

    assert_equal 1, queries.size
    assert_equal assessment.id, props[:selected][:id]
    assert_no_inertia_prop :assessments
  end

  def partial_headers(*keys)
    { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => "assessments/index", "X-Inertia-Partial-Data" => keys.join(",") }
  end

  # ---- score --------------------------------------------------------------

  test "the score is present and correct for scored statuses, including legacy string values" do
    create_legacy_assessment(company: @company, status: "comp", responses: sections_json("74", 70, 76, 71.0))
    create_legacy_assessment(company: @company, status: "needs_follow_up", responses: sections_json(40, 41, 42, 43))
    sign_in_as(@admin)

    visit

    assert_equal [ 73, 42 ].sort, rows.map { |row| row[:score] }.sort
  end

  test "pending and in-progress assessments have no score even if answers exist" do
    create_legacy_assessment(company: @company, status: "pending", responses: sections_json(80, 70, 75, 75))
    create_legacy_assessment(company: @company, status: "in_progress", responses: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    visit

    assert_equal [ nil, nil ], rows.map { |row| row[:score] }
  end

  test "a completed assessment with an unusable section is not scored" do
    create_legacy_assessment(company: @company, status: "completed", responses: sections_json(80, nil, 75, 75))
    create_legacy_assessment(company: @company, status: "completed", responses: nil)
    sign_in_as(@admin)

    visit

    assert_equal [ nil, nil ], rows.map { |row| row[:score] }
  end

  test "the drawer explains why a score is missing" do
    pending = create_legacy_assessment(company: @company, status: "pending", responses: sections_json(80, 70, 75, 75))
    broken = create_legacy_assessment(company: @company, status: "completed", responses: sections_json(80, nil, 75, 75))
    good = create_legacy_assessment(company: @company, status: "completed", responses: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    visit selected: pending.id
    assert_equal "awaiting_completion", props[:selected][:score_state]

    visit selected: broken.id
    assert_equal "incomplete", props[:selected][:score_state]
    assert_empty props[:selected][:sections]

    visit selected: good.id
    assert_equal "scored", props[:selected][:score_state]
    assert_equal 75, props[:selected][:score]
    assert_equal [ "Workstation setup", "Posture & movement", "Breaks & recovery", "Discomfort reported" ], props[:selected][:sections].map { |section| section[:label] }
    assert_equal [ 80, 70, 75, 75 ], props[:selected][:sections].map { |section| section[:value] }
  end

  # ---- status update ------------------------------------------------------

  test "changing the status saves, normalises and confirms" do
    assessment = create_assessment(company: @company, status: "pending", responses_json: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    patch assessment_path(assessment), params: { status: "done" }, headers: { "HTTP_REFERER" => assessments_url(status: "pending", selected: assessment.id) }

    assert_redirected_to assessments_url(status: "pending", selected: assessment.id)
    assert_equal "completed", assessment.reload.status
    follow_redirect!
    assert_equal "Status updated to Completed", flash[:notice]
  end

  test "an invalid status is rejected and nothing changes" do
    assessment = create_assessment(company: @company, status: "pending")
    sign_in_as(@admin)

    patch assessment_path(assessment), params: { status: "finished" }

    assert_response :redirect
    assert_equal "pending", assessment.reload.status
    assert_match(/Status must be one of/, flash[:alert])
  end

  test "moving to completed makes a score appear from existing answers" do
    assessment = create_assessment(company: @company, status: "in_progress", responses_json: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    visit selected: assessment.id
    assert_nil props[:selected][:score]

    patch assessment_path(assessment), params: { status: "completed" }
    visit selected: assessment.id
    assert_equal 75, props[:selected][:score]

    patch assessment_path(assessment), params: { status: "pending" }
    visit selected: assessment.id
    assert_nil props[:selected][:score], "going back to pending hides the score without destroying the answers"
    assert_equal 80, assessment.reload.responses_json.dig("section_scores", "workstation_setup")
  end

  # ---- remembered filters (cookie consent) -------------------------------

  test "filters are not remembered without consent" do
    create_legacy_assessment(company: @company, status: "completed")
    create_legacy_assessment(company: @company, status: "pending")
    sign_in_as(@admin)

    visit status: "completed"
    visit

    assert_equal "all", props[:filters][:status]
    assert_equal 2, rows.size
  end

  test "with consent the last status and preset are restored" do
    create_legacy_assessment(company: @company, status: "completed")
    create_legacy_assessment(company: @company, status: "pending")
    sign_in_as(@admin)
    post cookie_consent_path, params: { preferences: "true" }

    visit status: "completed", preset: "30"
    visit

    assert_equal "completed", props[:filters][:status]
    assert_equal "30", props[:filters][:preset]
    assert_equal 1, rows.size
  end

  test "explicit filters always beat the remembered ones, so Clear filters works" do
    create_legacy_assessment(company: @company, status: "completed")
    create_legacy_assessment(company: @company, status: "pending")
    sign_in_as(@admin)
    post cookie_consent_path, params: { preferences: "true" }
    visit status: "completed"

    visit status: "all", preset: "all"

    assert_equal 2, rows.size
  end

  test "withdrawing consent forgets the remembered filters" do
    create_legacy_assessment(company: @company, status: "completed")
    create_legacy_assessment(company: @company, status: "pending")
    sign_in_as(@admin)
    post cookie_consent_path, params: { preferences: "true" }
    visit status: "completed"

    post cookie_consent_path, params: { preferences: "false" }
    visit

    assert_equal "all", props[:filters][:status]
  end

  test "an update that forgets the status does not reset the assessment" do
    assessment = create_assessment(company: @company, status: "archived", responses_json: sections_json(80, 70, 75, 75))
    sign_in_as(@admin)

    patch assessment_path(assessment)

    assert_equal "archived", assessment.reload.status
    assert_match(/Status must be one of/, flash[:alert])
  end

  test "an assessment pointing at another company's employee does not expose that employee" do
    outsider = create_employee(company: @other_company, name: "Zed Outsider", department: "Secret Dept", email: "zed@example.com")
    create_legacy_assessment(company: @company, status: "completed", employee: outsider)
    sign_in_as(@admin)

    visit

    assert_equal 1, props[:pagination][:total], "the row is still counted and listed"
    assert_equal "Unknown employee", rows.first[:employee_name]
    assert_equal "—", rows.first[:department]
    assert_not_includes response.body, "Zed Outsider"
    assert_not_includes response.body, "Secret Dept"
  end
end
