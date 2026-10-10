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
end
