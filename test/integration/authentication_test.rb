require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_admin(company: @company)
  end

  test "an anonymous visitor is sent to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "signing in with valid details lands on the dashboard" do
    sign_in_as(@admin)

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_equal "Maya Reyes", shared_auth.dig(:admin, :name)
    assert_equal "MR", shared_auth.dig(:admin, :initials)
    assert_equal "Northwind Logistics", shared_auth.dig(:company, :name)
  end

  test "e-mail matching ignores case and whitespace" do
    post session_path, params: { email: "  MAYA@Example.com ", password: ActiveSupport::TestCase::TEST_PASSWORD }

    assert_redirected_to root_path
  end

  test "a wrong password and an unknown e-mail give the same generic error" do
    sign_in_as(@admin, password: "not-the-password")
    assert_redirected_to new_session_path
    wrong_password = flash_errors

    post session_path, params: { email: "nobody@example.com", password: "whatever-12345" }
    assert_redirected_to new_session_path
    unknown_email = flash_errors

    assert_equal wrong_password, unknown_email
    assert_equal [ "We couldn't sign you in with those details." ], wrong_password[:base]
    get root_path
    assert_redirected_to new_session_path
  end

  test "blank or malformed credentials are rejected without raising" do
    post session_path, params: { email: "", password: "" }
    assert_redirected_to new_session_path

    post session_path, params: { email: [ "a" ], password: { b: 1 } }
    assert_redirected_to new_session_path
  end

  test "signing out ends the session" do
    sign_in_as(@admin)
    delete session_path

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
  end

  test "an idle session expires" do
    sign_in_as(@admin)

    travel_to (Authentication::IDLE_TIMEOUT + 1.minute).from_now do
      get root_path
      assert_redirected_to new_session_path
    end
  end

  test "the session id is replaced on sign in" do
    get new_session_path
    before = request.session.id.to_s

    sign_in_as(@admin)

    assert_not_equal before, request.session.id.to_s
  end

  test "the company comes from the session, never from a request parameter" do
    other = create_company(name: "Harbor & Pine Clinics")
    sign_in_as(@admin)

    get root_path, params: { company_id: other.id }

    assert_response :success
    assert_equal "Northwind Logistics", shared_auth.dig(:company, :name)
  end

  test "authenticated pages are never cached" do
    sign_in_as(@admin)
    get root_path

    assert_equal "no-store", response.headers["Cache-Control"]
  end

  private

  def flash_errors
    follow_redirect!
    inertia.props[:errors].with_indifferent_access
  end

  def shared_auth
    inertia.props[:auth].with_indifferent_access
  end
end
