require "test_helper"

class NewAssessmentTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @employee = create_employee(company: @company, name: "Priya Carter", department: "Finance")
    @other_company = create_company(name: "Harbor & Pine Clinics")
    @other_employee = create_employee(company: @other_company, name: "Jonas Weber", department: "Clinic")
    sign_in_as(@admin)
  end

  def scores(*values)
    ScoreCalculator::SECTIONS.keys.zip(values).to_h
  end

  def create_via_form(**params)
    post assessments_path, params: { employee_id: @employee.id, status: "completed" }.merge(params)
  end

  # Inertia hands validation errors to the page that follows the redirect.
  def problems
    follow_redirect!
    inertia.props[:errors][:assessment]
  end

  # ---- happy paths -------------------------------------------------------

  test "creates a scored assessment for an existing employee of the signed-in company" do
    assert_difference -> { @company.assessments.count }, 1 do
      create_via_form(scores: scores("80", "70", "75", "75"))
    end

    assessment = @company.assessments.order(:id).last
    assert_equal @employee, assessment.employee
    assert_equal "completed", assessment.status
    assert_equal({ "workstation_setup" => 80, "posture_movement" => 70, "breaks_recovery" => 75, "discomfort_reported" => 75 }, assessment.responses_json["section_scores"])
    assert_redirected_to assessments_path(selected: assessment.id)
    follow_redirect!
    assert_equal 75, inertia.props[:selected][:score]
    assert_equal "Assessment A-#{assessment.id} created", flash[:notice]
  end

  test "can create a new employee in the same step, inside the signed-in company" do
    assert_difference -> { @company.employees.count }, 1 do
      create_via_form(employee_id: "new", employee_name: "  Lucia   Okafor ", department: " Warehouse ", status: "pending")
    end

    employee = @company.employees.find_by!(name: "Lucia Okafor")
    assert_equal "Warehouse", employee.department
    assert_equal employee, @company.assessments.order(:id).last.employee
    assert_equal 0, @other_company.employees.where(name: "Lucia Okafor").count
  end

  test "a legacy alias is normalised and an unscored status keeps no scores" do
    create_via_form(status: "done", scores: scores(90, 90, 90, 90))
    assert_equal "completed", @company.assessments.order(:id).last.status

    create_via_form(status: "in_progress", scores: scores(90, 90, 90, 90))
    pending = @company.assessments.order(:id).last
    assert_equal "in_progress", pending.status
    assert_equal({}, pending.responses_json)
  end

  test "a completed assessment may be saved without scores and shows as not scored" do
    create_via_form
    assessment = @company.assessments.order(:id).last

    get assessments_path(selected: assessment.id)

    assert_nil inertia.props[:selected][:score]
    assert_equal "incomplete", inertia.props[:selected][:score_state]
  end

  test "the new assessment appears in the dashboard counts and in a CSV export" do
    create_via_form(scores: scores(60, 60, 60, 60))
    assessment = @company.assessments.order(:id).last

    get assessments_path(status: "all", preset: "all")
    assert_equal 1, inertia.props[:counts][:all]
    assert_includes inertia.props[:assessments].map { |row| row[:id] }, assessment.id

    scope = AssessmentExports::Scope.call(@company, from: nil, to: nil, status: "all")
    assert_includes scope.pluck(:id), assessment.id
  end

  # ---- tenancy -----------------------------------------------------------

  test "another company's employee cannot be used" do
    assert_no_difference -> { Assessment.count } do
      create_via_form(employee_id: @other_employee.id)
    end

    assert_response :not_found
  end

  test "a company_id in the request cannot choose the tenant" do
    create_via_form(company_id: @other_company.id, "company[id]" => @other_company.id)

    assert_equal 1, @company.assessments.count
    assert_equal 0, @other_company.assessments.count
  end

  test "the employee list is lazy and only ever holds the signed-in company's employees" do
    get assessments_path
    assert_no_inertia_prop :employees

    get assessments_path, headers: {
      "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => "assessments/index", "X-Inertia-Partial-Data" => "employees"
    }

    assert_equal [ { id: @employee.id, name: "Priya Carter", department: "Finance" } ], inertia.props[:employees].map(&:symbolize_keys)
  end

  # ---- validation --------------------------------------------------------

  test "an employee is required" do
    assert_no_difference -> { Assessment.count } do
      create_via_form(employee_id: "")
    end

    assert_includes problems, "Choose an employee."
  end

  test "a new employee needs a name, and nothing is left behind when the assessment is rejected" do
    assert_no_difference -> { Assessment.count + Employee.count } do
      create_via_form(employee_id: "new", employee_name: "   ")
      assert_includes problems, "Enter the new employee's name."

      create_via_form(employee_id: "new", employee_name: "Sam Ito", status: "on hold")
      assert_match(/Status must be one of/, problems.join)
    end
  end

  test "scores are four whole numbers from 0 to 100, or none" do
    bad = {
      "only three" => scores(80, 70, 75, ""),
      "above 100" => scores(80, 70, 75, 101),
      "negative" => scores(80, 70, 75, -1),
      "decimal" => scores(80, 70, 75, "7.5"),
      "text" => scores(80, 70, 75, "high"),
      "hex" => scores(80, 70, 75, "0x1A")
    }

    assert_no_difference -> { Assessment.count } do
      bad.each do |label, value|
        create_via_form(scores: value)
        assert_response :redirect, label
        assert problems.any? { |message| message.match?(/section scores/i) }, "#{label} should be rejected"
      end
    end
  end

  test "an overlong name is rejected" do
    assert_no_difference -> { Employee.count } do
      create_via_form(employee_id: "new", employee_name: "x" * (NewAssessment::NAME_LIMIT + 1))
    end

    assert problems.any? { |message| message.include?("too long") }
  end

  # ---- access and hygiene ------------------------------------------------

  test "creating requires sign in" do
    delete session_path
    assert_no_difference -> { Assessment.count } do
      create_via_form
    end

    assert_redirected_to new_session_path
  end

  test "the section scores never reach the request log" do
    log = captured_log { create_via_form(scores: scores(93, 61, 47, 58)) }

    assert_not_includes log, %("workstation_setup"=>"93")
    assert_not_includes log, %("posture_movement"=>"61")
    assert_match(/"scores"=>"\[FILTERED\]"/, log)
  end

  test "the new employee's name never reaches the log" do
    log = captured_log { create_via_form(employee_id: "new", employee_name: "Zanele Mokoena", department: "Warehouse") }

    assert_not_includes log, "Zanele Mokoena"
  end
end
