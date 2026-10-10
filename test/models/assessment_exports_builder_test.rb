require "test_helper"
require "csv"

class AssessmentExportsBuilderTest < ActiveSupport::TestCase
  SECRET_EMAIL = "amara.private@example.com".freeze
  SECRET_TEXT = "lower back pain secret".freeze

  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @other = create_company(name: "Harbor & Pine Clinics")
    @amara = create_employee(company: @company, name: "Amara Okafor", email: SECRET_EMAIL, department: "Warehouse")
  end

  def build(batch_size: AssessmentExports::Builder::BATCH_SIZE, **attrs)
    export = AssessmentExport.create!({ company: @company, admin: @admin }.merge(attrs))
    export.claim!
    AssessmentExports::Builder.new(export, batch_size: batch_size).call
    export.reload
  end

  def csv_for(export)
    CSV.parse(export.file.download, headers: true)
  end

  def seed_rows
    create_legacy_assessment(company: @company, employee: @amara, status: "comp", created_at: Time.utc(2026, 9, 10, 9),
      responses: { "free_text" => { "q7" => SECRET_TEXT } }.merge(sections_json(80, 70, 75, 75)))
    create_legacy_assessment(company: @company, employee: @amara, status: nil, created_at: Time.utc(2026, 9, 12, 9))
    create_legacy_assessment(company: @company, employee: @amara, status: "archived", created_at: Time.utc(2026, 9, 20, 9),
      responses: sections_json("74", 70, 76, 71))
  end

  test "the file has exactly the six agreed columns" do
    seed_rows

    export = build

    assert_equal %w[assessment_id employee_ref department status score created_at], csv_for(export).headers
    assert_equal "text/csv", export.file.content_type
  end

  test "rows carry canonical statuses, correct scores and dates" do
    seed_rows

    rows = csv_for(build).map(&:to_h).sort_by { |row| row["created_at"] }

    assert_equal %w[completed pending archived], rows.map { |row| row["status"] }
    assert_equal [ "75", nil, "73" ], rows.map { |row| row["score"] }
    assert_equal %w[2026-09-10 2026-09-12 2026-09-20], rows.map { |row| row["created_at"] }
    assert(rows.all? { |row| row["assessment_id"].match?(/\AA-\d+\z/) })
  end

  test "names, e-mail addresses, free text and raw responses never reach the file" do
    seed_rows

    body = build.file.download

    [ SECRET_EMAIL, SECRET_TEXT, "Amara", "Okafor", "free_text", "responses", "employee_email", "q7" ].each do |secret|
      assert_not_includes body, secret
    end
  end

  test "employees appear only as a stable one-way reference" do
    seed_rows

    refs = csv_for(build).map { |row| row["employee_ref"] }

    assert_equal 1, refs.uniq.size
    assert_match(/\Aemp_[0-9a-f]{12}\z/, refs.first)
    assert_equal EmployeeRef.for(company_id: @company.id, employee_id: @amara.id), refs.first
  end

  test "only the exporting company's rows are included" do
    seed_rows
    intruder = create_employee(company: @other, name: "Jonas Weber", department: "Clinic")
    create_legacy_assessment(company: @other, employee: intruder, status: "completed", created_at: Time.utc(2026, 9, 11, 9))

    export = build

    assert_equal 3, csv_for(export).size
    assert_equal 3, export.row_count
    assert_not_includes export.file.download, "Clinic"
  end

  test "the date range includes the whole of both end days" do
    create_legacy_assessment(company: @company, employee: @amara, status: "completed", created_at: Time.utc(2026, 9, 1, 0, 0, 1))
    create_legacy_assessment(company: @company, employee: @amara, status: "completed", created_at: Time.utc(2026, 9, 30, 23, 59, 59))
    create_legacy_assessment(company: @company, employee: @amara, status: "completed", created_at: Time.utc(2026, 8, 31, 23, 59, 59))
    create_legacy_assessment(company: @company, employee: @amara, status: "completed", created_at: Time.utc(2026, 10, 1, 0, 0, 1))

    export = build(from_date: Date.new(2026, 9, 1), to_date: Date.new(2026, 9, 30))

    assert_equal 2, export.row_count
  end

  test "the status filter matches every legacy spelling" do
    [ "completed", "comp", "done", "complete" ].each { |raw| create_legacy_assessment(company: @company, employee: @amara, status: raw) }
    [ "pending", nil, "", "n/a" ].each { |raw| create_legacy_assessment(company: @company, employee: @amara, status: raw) }

    assert_equal 4, build(status_filter: "completed").row_count
    assert_equal({ "completed" => 4 }, csv_for(AssessmentExport.last).map { |row| row["status"] }.tally)
    assert_equal 4, build(status_filter: "pending").row_count
    assert_equal 8, build(status_filter: "all").row_count
  end

  test "an unknown legacy status is exported as needs_follow_up" do
    create_legacy_assessment(company: @company, employee: @amara, status: "on hold")

    assert_equal [ "needs_follow_up" ], csv_for(build(status_filter: "needs_follow_up")).map { |row| row["status"] }
  end

  test "spreadsheet formulas in a department are neutralised" do
    attacker = create_employee(company: @company, name: "X", department: "=HYPERLINK(\"http://evil\",\"x\")")
    plus = create_employee(company: @company, name: "Y", department: "+1+1")
    create_legacy_assessment(company: @company, employee: attacker, status: "completed")
    create_legacy_assessment(company: @company, employee: plus, status: "completed")

    departments = csv_for(build).map { |row| row["department"] }

    assert(departments.all? { |value| value.start_with?("'") }, departments.inspect)
  end

  test "commas, quotes and newlines in a department are escaped properly" do
    odd = create_employee(company: @company, name: "Z", department: "R&D, \"Labs\"\nNorth")
    create_legacy_assessment(company: @company, employee: odd, status: "completed")

    assert_equal "R&D, \"Labs\"\nNorth", csv_for(build).first["department"]
  end

  test "progress is saved after every batch and ends at 100" do
    5.times { create_legacy_assessment(company: @company, employee: @amara, status: "completed") }
    updates = 0
    counter = ->(*, payload) { updates += 1 if payload[:sql].start_with?('UPDATE "assessment_exports"') && payload[:sql].include?('"progress"') }

    export = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { build(batch_size: 2) }

    assert_equal 5, export.row_count
    assert_equal 100, export.progress
    assert_operator updates, :>=, 3, "one progress write per batch of two"
  end

  test "an export that exceeds its time budget stops" do
    5.times { create_legacy_assessment(company: @company, employee: @amara, status: "completed") }
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.claim!

    assert_raises(AssessmentExports::TimeBudgetExceeded) do
      AssessmentExports::Builder.new(export, max_seconds: -1, batch_size: 2).call
    end
  end

  test "the matching rows are the same ones the preview counts" do
    seed_rows
    filters = { from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 15), status: "all" }

    assert_equal 2, AssessmentExports::Scope.call(@company, **filters).count
    assert_equal 2, build(from_date: filters[:from], to_date: filters[:to]).row_count
  end

  test "the export never even reads names, e-mail addresses or free text" do
    seed_rows
    queries = []
    capture = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "assessments"') && payload[:name] != "SCHEMA" }

    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") { build }

    selects = queries.select { |sql| sql.start_with?("SELECT") && sql.include?("section_scores") }
    assert_not_empty selects, "expected the batch SELECT to be captured"
    selects.each do |sql|
      assert_no_match(/employees\.name|employee_email|employees\.email|"email"|free_text|\bresponses_json\b(?! ->)/, sql)
      assert_includes sql, "responses_json -> 'section_scores'"
    end
  end

  test "a row pointing at another company's employee exports with no foreign department" do
    stranger = create_employee(company: @other, name: "Zed Outsider", department: "Secret Dept")
    create_legacy_assessment(company: @company, employee: stranger, status: "completed")

    body = build.file.download

    assert_not_includes body, "Secret Dept"
    assert_not_includes body, "Zed"
    assert_equal [ nil ], CSV.parse(body, headers: true).map { |row| row["department"] }, "an unknown department is an empty cell, not a UI placeholder"
  end
end
