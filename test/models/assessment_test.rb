require "test_helper"

class AssessmentTest < ActiveSupport::TestCase
  test "rejects an employee from another company" do
    northwind = create_company
    other = create_company(name: "Harbor & Pine Clinics")
    outsider = create_employee(company: other)

    assessment = Assessment.new(company: northwind, employee: outsider)

    assert_not assessment.valid?
    assert_includes assessment.errors[:employee], "must belong to the same company"
  end

  test "inspect never prints personal identifiers or raw responses" do
    company = create_company
    assessment = create_assessment(
      company: company,
      employee_email: "amara@example.com",
      responses_json: { "free_text" => { "q7" => "lower back pain" } }
    )

    assert_no_match(/amara@example\.com|lower back pain/, assessment.inspect)
    assert_match(/\[FILTERED\]/, assessment.inspect)
  end

  test "a new record without a status defaults to pending" do
    assert_equal "pending", create_assessment(company: create_company).status
  end

  test "known aliases are normalised on create" do
    assessment = create_assessment(company: create_company, status: "comp")
    assert_equal "completed", assessment.reload.status
  end

  test "unknown statuses are rejected on create" do
    company = create_company
    assessment = Assessment.new(company: company, employee: create_employee(company: company), status: "finished")

    assert_not assessment.valid?
    assert_match(/must be one of/, assessment.errors[:status].first)
  end

  test "updates are normalised and unknown values are rejected" do
    assessment = create_assessment(company: create_company, status: "pending")

    assert assessment.update(status: "DONE")
    assert_equal "completed", assessment.reload.status

    assert_not assessment.update(status: "bogus")
    assert_equal "completed", assessment.reload.status
  end

  test "saving a legacy row with an unrelated change also normalises its status" do
    assessment = create_assessment(company: create_company)
    assessment.update_columns(status: "done") # simulate legacy data written before the change

    assessment.update!(employee_email: "someone@example.com")

    assert_equal "completed", assessment.reload.status
  end

  test "explicitly blanking an existing status is rejected, not turned into pending" do
    assessment = create_assessment(company: create_company, status: "archived")

    [ "", "  ", nil ].each do |blank|
      assert_not assessment.update(status: blank), "#{blank.inspect} must not be accepted"
      assert_equal "archived", assessment.reload.status
    end
  end

  test "a legacy blank status that is left alone still normalises on an unrelated save" do
    assessment = create_assessment(company: create_company)
    assessment.update_columns(status: nil)

    assessment.update!(employee_email: "someone@example.com")

    assert_equal "pending", assessment.reload.status
  end
end
