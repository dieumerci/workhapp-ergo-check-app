require "test_helper"

# Runs requests with the log at DEBUG (so SQL and parameters are written) and
# reads back what was actually logged. Sensitive values must never appear;
# the non-sensitive ones the team needs for debugging must.
class LogHygieneTest < ActionDispatch::IntegrationTest
  SECRET_EMAIL = "amara.private@example.com".freeze
  SECRET_TEXT = "lower back pain secret".freeze

  setup do
    @company = create_company
    @admin = create_admin(company: @company, email: "maya.private@example.com")
    @employee = create_employee(company: @company, name: "Amara Okafor", email: SECRET_EMAIL)
    @assessment = create_assessment(
      company: @company, employee: @employee, status: "completed", employee_email: SECRET_EMAIL,
      responses_json: { "free_text" => { "q7" => SECRET_TEXT } }.merge(sections_json(80, 70, 75, 75))
    )
  end

  def assert_no_leak(log, *secrets)
    secrets.each { |secret| assert_not_includes log, secret, "#{secret.inspect} was written to the log" }
  end

  test "request parameters carrying personal data are filtered, harmless ones are kept" do
    sign_in_as(@admin)

    log = captured_log do
      get assessments_path, params: {
        status: "completed", from: "2026-09-01", to: "2026-09-30",
        employee_email: SECRET_EMAIL, responses_json: { q7: SECRET_TEXT }.to_json, company_id: 999
      }
    end

    assert_no_leak log, SECRET_EMAIL, SECRET_TEXT
    assert_match(/"status"=>"completed"/, log)
    assert_match(/"from"=>"2026-09-01"/, log)
    assert_match(/"employee_email"=>"\[FILTERED\]"/, log)
    assert_match(/"responses_json"=>"\[FILTERED\]"/, log)
  end

  test "the query string in the request line is filtered too" do
    sign_in_as(@admin)

    log = captured_log { get assessments_path, params: { status: "completed", employee_email: SECRET_EMAIL } }

    assert_no_leak log, SECRET_EMAIL
    assert_match(/Started GET "\/assessments\?[^"]*status=completed/, log)
  end

  test "browsing the dashboard and the drawer never logs stored e-mails or free text" do
    sign_in_as(@admin)

    log = captured_log do
      get assessments_path
      get assessments_path, params: { selected: @assessment.id }
    end

    assert_no_leak log, SECRET_EMAIL, SECRET_TEXT, "Amara.Okafor"
  end

  test "writing an assessment logs filtered bind values, not the data" do
    log = captured_log do
      create_assessment(
        company: @company, employee: @employee, employee_email: SECRET_EMAIL,
        responses_json: { "free_text" => { "q7" => SECRET_TEXT } }
      )
    end

    assert_no_leak log, SECRET_EMAIL, SECRET_TEXT
    assert_match(/INSERT INTO "assessments"/, log)
  end

  test "updating a status logs the status but nothing personal" do
    sign_in_as(@admin)

    log = captured_log { patch assessment_path(@assessment), params: { status: "archived" } }

    assert_no_leak log, SECRET_EMAIL, SECRET_TEXT
    assert_match(/"status"=>"archived"/, log)
  end

  test "signing in never logs the e-mail, password or verification code" do
    log = captured_log { attempt_sign_in(email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD) }

    assert_no_leak log, @admin.email, ActiveSupport::TestCase::TEST_PASSWORD, KNOWN_CAPTCHA
    assert_match(/"password"=>"\[FILTERED\]"/, log)
    assert_match(/"captcha"=>"\[FILTERED\]"/, log)
  end

  test "records do not print personal data when inspected" do
    assert_no_match(/#{SECRET_EMAIL}|#{SECRET_TEXT}/, @assessment.inspect)
    assert_no_match(/Amara Okafor|#{SECRET_EMAIL}/, @employee.inspect)
    assert_no_match(/maya\.private@example\.com|password_digest=.\$2/, @admin.inspect)
  end
end
