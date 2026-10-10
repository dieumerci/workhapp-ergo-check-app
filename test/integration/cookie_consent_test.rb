require "test_helper"

class CookieConsentTest < ActionDispatch::IntegrationTest
  test "the choice is exposed to the page, starting undecided" do
    get new_session_path

    assert_equal({ "decided" => false, "preferences" => false }, inertia.props[:cookie_consent].stringify_keys)
  end

  test "accepting works before signing in and is remembered" do
    post cookie_consent_path, params: { preferences: "true" }
    assert_response :redirect

    get new_session_path
    assert_equal({ "decided" => true, "preferences" => true }, inertia.props[:cookie_consent].stringify_keys)
  end

  test "essential only is remembered as a decision without optional cookies" do
    post cookie_consent_path, params: { preferences: "false" }

    get new_session_path
    assert_equal({ "decided" => true, "preferences" => false }, inertia.props[:cookie_consent].stringify_keys)
  end

  test "the consent cookie is HttpOnly, SameSite=Lax and lasts about a year" do
    post cookie_consent_path, params: { preferences: "true" }

    header = Array(response.headers["Set-Cookie"]).join("\n")
    cookie = header.lines.find { |line| line.start_with?("ergocheck_consent=") }
    assert cookie, "expected the consent cookie to be set"
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)
    expires = Time.httpdate(cookie[/expires=([^;]+)/i, 1])
    assert_in_delta 12.months.from_now.to_i, expires.to_i, 5.minutes.to_i
  end

  test "anything other than true counts as declining" do
    post cookie_consent_path, params: { preferences: "yes please" }

    get new_session_path
    assert_equal false, inertia.props[:cookie_consent][:preferences]
  end

  test "it never redirects off-site" do
    post cookie_consent_path, params: { preferences: "true" }, headers: { "HTTP_REFERER" => "https://evil.example/phish" }

    assert_response :redirect
    assert_equal "www.example.com", URI(response.location).host
  end
end
