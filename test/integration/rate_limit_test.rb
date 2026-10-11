require "test_helper"

# Every rate limit in the app, exercised for real. Rails keeps the counters in the cache, so
# these only mean something because the test environment uses a real store (a null store
# never counts). A counter's key is built from the controller and the limit's `name:`, so two
# limits in one controller that are not named share a counter: the export tests below guard that.
class RateLimitTest < ActionDispatch::IntegrationTest
  GENERIC_LIMIT = "Too many attempts. Please wait a few minutes and try again.".freeze

  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @employee = create_employee(company: @company)
    create_assessment(company: @company, employee: @employee, status: "completed")
  end

  # A wrong sign-in from a chosen client address, returning the errors the page would show.
  def failed_sign_in(email, ip:)
    env = { "REMOTE_ADDR" => ip }
    get captcha_path, env: env
    post session_path, params: { email: email, password: "wrong-password-123", captcha: "00000" }, env: env
    follow_redirect!
    inertia.props[:errors].with_indifferent_access
  end

  def limited?(errors)
    errors[:base]&.include?(GENERIC_LIMIT)
  end

  # ---- sign-in -----------------------------------------------------------

  test "one account is limited after six attempts in ten minutes, whatever address they come from" do
    6.times { |i| assert_not limited?(failed_sign_in("target@example.com", ip: "10.1.0.#{i + 1}")), "attempt #{i + 1} should be answered normally" }

    assert limited?(failed_sign_in("target@example.com", ip: "10.1.0.99")), "the seventh attempt should be refused"
  end

  test "one address is limited after ten attempts in three minutes, whichever accounts it tries" do
    10.times { |i| assert_not limited?(failed_sign_in("person#{i}@example.com", ip: "10.2.0.1")), "attempt #{i + 1} should be answered normally" }

    assert limited?(failed_sign_in("someone-new@example.com", ip: "10.2.0.1")), "the eleventh attempt should be refused"
  end

  test "a limited account does not limit another account or another address" do
    7.times { |i| failed_sign_in("target@example.com", ip: "10.3.0.#{i + 1}") }

    assert_not limited?(failed_sign_in("someone-else@example.com", ip: "10.3.1.1"))
  end

  test "a correct sign-in still works after one failed attempt" do
    assert_not limited?(failed_sign_in("target@example.com", ip: "10.4.0.1"))
    sign_in_as(@admin)

    assert_redirected_to root_path
  end

  # ---- CAPTCHA -----------------------------------------------------------

  test "the text question is limited to six requests an hour" do
    6.times do
      get captcha_question_path
      assert_response :success
    end

    get captcha_question_path

    assert_response :too_many_requests
    assert_match(/Too many requests/, response.parsed_body["error"])
  end

  test "the text question's counter is separate from the image's" do
    40.times { get captcha_path }
    get captcha_question_path

    assert_response :success
  end

  test "the CAPTCHA image is limited to forty requests a minute" do
    40.times do
      get captcha_path
      assert_response :success
    end

    get captcha_path

    assert_response :too_many_requests
  end

  # ---- exports -----------------------------------------------------------

  test "export previews do not use up the hourly export budget" do
    sign_in_as(@admin)
    15.times do
      get preview_exports_path, params: { status: "completed" }
      assert_response :success
    end

    assert_difference -> { AssessmentExport.count }, 1 do
      post exports_path, params: { status: "completed" }, headers: { "HTTP_REFERER" => exports_url }
    end
  end

  test "export requests do not use up the preview budget" do
    sign_in_as(@admin)
    3.times { post exports_path, params: { status: "completed" }, headers: { "HTTP_REFERER" => exports_url } }

    60.times do
      get preview_exports_path, params: { status: "completed" }
      assert_response :success
    end
    get preview_exports_path, params: { status: "completed" }

    assert_response :too_many_requests
    assert_match(/Too many requests/, response.parsed_body["error"])
  end

  test "the eleventh export request in an hour is refused with a clear message" do
    sign_in_as(@admin)
    10.times { post exports_path, params: { status: "completed" }, headers: { "HTTP_REFERER" => exports_url } }
    assert_not_equal "Too many export requests. Please try again later.", flash[:alert]

    post exports_path, params: { status: "completed" }, headers: { "HTTP_REFERER" => exports_url }

    assert_redirected_to exports_url
    assert_equal "Too many export requests. Please try again later.", flash[:alert]
  end

  # ---- new assessments ---------------------------------------------------

  test "the thirty-first new assessment in a minute is refused" do
    sign_in_as(@admin)
    30.times { post assessments_path, params: { employee_id: "" }, headers: { "HTTP_REFERER" => assessments_url } }
    assert_not_equal "Too many new assessments in a short time. Please wait a moment.", flash[:alert]

    post assessments_path, params: { employee_id: "" }, headers: { "HTTP_REFERER" => assessments_url }

    assert_equal "Too many new assessments in a short time. Please wait a moment.", flash[:alert]
  end
end
