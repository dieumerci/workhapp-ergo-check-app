# Self-hosted CAPTCHA for the sign-in form.
#
# A random code is rendered into a PNG (Captcha::Renderer), so the answer is
# never present in the page's DOM or markup. Only an HMAC digest of the code is
# stored, in a server-side CaptchaChallenge row; the browser's session holds just
# that row's id. Each challenge is single use because verifying DELETES the row:
# replaying an old cookie finds nothing to verify against. (A digest kept inside
# a cookie-store session could not be single-use, since the client holds the only
# copy and can resend it.)
module Captcha
  CODE_LENGTH = 5
  TTL = CaptchaChallenge::TTL

  mattr_accessor :code_generator, default: -> {
    Array.new(CODE_LENGTH) { SecureRandom.random_number(10) }.join
  }

  module_function

  # Creates a new challenge, remembers its id in +session+ and returns the code.
  # Any earlier challenge for this session is discarded.
  def issue(session, now: Time.current)
    CaptchaChallenge.discard(session.delete(:captcha_id))
    code = code_generator.call
    session[:captcha_id] = CaptchaChallenge.issue(digest(code), now: now).id
    code
  end

  # True only if +answer+ matches the challenge currently held by +session+.
  # The challenge is consumed whether or not the answer is right.
  def verify?(session, answer, now: Time.current)
    stored_digest = CaptchaChallenge.consume(session.delete(:captcha_id), now: now)
    return false unless stored_digest

    candidate = answer.to_s.gsub(/\s+/, "")
    return false unless candidate.match?(/\A\d{#{CODE_LENGTH}}\z/)

    ActiveSupport::SecurityUtils.secure_compare(stored_digest, digest(candidate))
  end

  def digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", key, code.to_s)
  end

  def key
    Rails.application.key_generator.generate_key("ergocheck captcha")
  end
end
