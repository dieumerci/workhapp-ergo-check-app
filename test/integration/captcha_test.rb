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

  test "the browser holds only a challenge id; the server holds a digest, never the answer" do
    get captcha_path

    challenge = CaptchaChallenge.last
    assert_equal 64, challenge.digest.length
    assert_not_includes challenge.digest, KNOWN_CAPTCHA
    assert_equal challenge.id, request.session[:captcha_id]
    assert_nil request.session[:captcha], "the digest must not be stored in the cookie"
  end

  test "a captured cookie cannot replay a solved challenge" do
    get captcha_path
    original_cookie = cookies["_ergocheck_session"]

    # the legitimate attempt uses the challenge up (wrong password, so no sign-in)
    post session_path, params: { email: @admin.email, password: "wrong-password-1", captcha: KNOWN_CAPTCHA }
    assert_equal 0, CaptchaChallenge.count, "verifying must delete the challenge"

    # an attacker replays the ORIGINAL cookie with the right code and the right password
    cookies["_ergocheck_session"] = original_cookie
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: KNOWN_CAPTCHA }

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
  end

  test "ten replays of one cookie still pass the CAPTCHA at most once" do
    get captcha_path
    original_cookie = cookies["_ergocheck_session"]
    results = Array.new(10) do
      cookies["_ergocheck_session"] = original_cookie
      post session_path, params: { email: "nobody@example.com", password: "whatever-12345", captcha: KNOWN_CAPTCHA }
      follow_redirect!
      inertia.props[:errors].with_indifferent_access.key?(:captcha)
    end

    assert_equal 1, results.count(false), "exactly one attempt may get past the CAPTCHA"
    assert_equal 9, results.count(true)
  end

  test "issuing a new challenge discards the previous one" do
    get captcha_path
    first = CaptchaChallenge.last.id
    get captcha_path

    assert_not CaptchaChallenge.exists?(first)
    assert_equal 1, CaptchaChallenge.count
  end

  test "expired challenges are purged" do
    get captcha_path
    CaptchaChallenge.update_all(expires_at: 2.hours.ago)

    CaptchaChallenge.purge_expired

    assert_equal 0, CaptchaChallenge.count
  end

  test "a forged challenge id is rejected without raising" do
    [ "1; DROP TABLE captcha_challenges", "abc", "-1", "9" * 40, "" ].each do |bad|
      assert_nil CaptchaChallenge.consume(bad)
    end
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

  # ---- the accessible text alternative ---------------------------------------

  def ask_question
    get captcha_question_path
    assert_response :success
    response.parsed_body["question"]
  end

  test "a text question is served as JSON, readable by a screen reader, with no answer in it" do
    question = ask_question

    assert_equal ActionDispatch::IntegrationTest::KNOWN_QUESTION.first, question
    assert_equal "application/json", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_not_includes response.body, "37", "the answer must never be sent to the browser"
    assert_equal 64, CaptchaChallenge.last.digest.length
  end

  test "signing in with the right answer to the text question works" do
    ask_question
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: "37" }

    assert_redirected_to root_path
  end

  test "a wrong answer to the text question is rejected even with the right password" do
    ask_question
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: "38" }

    assert_redirected_to new_session_path
    get root_path
    assert_redirected_to new_session_path
  end

  test "a text question is single use and cannot be replayed from a copied cookie" do
    ask_question
    original_cookie = cookies["_ergocheck_session"]
    post session_path, params: { email: @admin.email, password: "wrong-password-1", captcha: "37" }

    cookies["_ergocheck_session"] = original_cookie
    post session_path, params: { email: @admin.email, password: ActiveSupport::TestCase::TEST_PASSWORD, captcha: "37" }

    assert_redirected_to new_session_path
  end

  test "asking for a text question replaces an image challenge, and the reverse" do
    get captcha_path
    image_challenge = CaptchaChallenge.last.id
    ask_question

    assert_not CaptchaChallenge.exists?(image_challenge)
    assert_equal 1, CaptchaChallenge.count
  end

  test "the text question needs no sign-in" do
    get captcha_question_path

    assert_response :success
  end

  test "the real generator makes sensible sums" do
    questions = Array.new(200) { DEFAULT_QUESTION_GENERATOR.call }

    assert(questions.all? { |_, answer| answer.match?(/\A\d{1,3}\z/) && answer.to_i >= 0 })
    assert(questions.all? { |question, _| question.match?(/\AWhat is \d+ (plus|minus) \d+\?/) })
    assert_operator questions.map(&:first).uniq.size, :>, 20, "questions should vary"
  end
end
