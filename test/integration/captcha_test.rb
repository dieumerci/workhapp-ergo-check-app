require "test_helper"

class CaptchaTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin(company: create_company)
  end

  test "serves a PNG that is never cached" do
    get captcha_path

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    image = ChunkyPNG::Image.from_blob(response.body)
    assert_equal [ Captcha::Renderer::WIDTH, Captcha::Renderer::HEIGHT ], [ image.width, image.height ]
  end

  test "the session holds a digest, never the answer" do
    get captcha_path

    stored = request.session[:captcha]
    assert_equal 64, stored["digest"].length
    assert_not_includes stored.to_s, KNOWN_CAPTCHA
  end

  test "the image differs between codes" do
    a = Captcha::Renderer.png("11111", random: Random.new(1))
    b = Captcha::Renderer.png("22222", random: Random.new(1))

    assert_not_equal a, b
  end

  test "signing in succeeds with the right code" do
    sign_in_as(@admin)

    assert_redirected_to root_path
  end

  test "a wrong code is rejected even with the right password" do
    attempt_sign_in(email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: "00000")

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match(/didn't match/, inertia.props[:errors][:captcha].first)
  end

  test "a missing or malformed code is rejected" do
    [ nil, "", "abc", "1234", "482130" ].each do |bad|
      attempt_sign_in(email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: bad)
      assert_redirected_to new_session_path, "expected #{bad.inspect} to be rejected"
    end
    get root_path
    assert_redirected_to new_session_path
  end

  test "submitting without ever loading the image is rejected" do
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: KNOWN_CAPTCHA }

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
  end

  test "a challenge can only be used once" do
    get captcha_path
    post session_path, params: { email: @admin.email, password: "wrong-password-1", captcha: KNOWN_CAPTCHA }
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: KNOWN_CAPTCHA }

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
  end

  test "a challenge expires" do
    get captcha_path

    travel_to (Captcha::TTL + 1.second).from_now do
      post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: KNOWN_CAPTCHA }
      assert_redirected_to new_session_path
    end
  end

  test "the answer is filtered from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("captcha" => KNOWN_CAPTCHA)["captcha"]
  end
end
