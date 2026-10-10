# Self-hosted CAPTCHA for the sign-in form.
#
# A random code is rendered into a PNG (Captcha::Renderer), so the answer is
# never present in the page's DOM or markup. Only an HMAC digest of the code
# is kept in the (encrypted) session, together with an expiry. Each challenge
# is single use: any verification attempt, right or wrong, consumes it.
module Captcha
  CODE_LENGTH = 5
  TTL = 5.minutes

  mattr_accessor :code_generator, default: -> {
    Array.new(CODE_LENGTH) { SecureRandom.random_number(10) }.join
  }

  module_function

  # Creates a new challenge, remembers its digest in +session+ and returns the code.
  def issue(session, now: Time.current)
    code = code_generator.call
    session[:captcha] = { "digest" => digest(code), "expires_at" => (now + TTL).to_i }
    code
  end

  # True only if +answer+ matches the challenge currently stored in +session+.
  def verify?(session, answer, now: Time.current)
    stored = session.delete(:captcha)
    return false unless stored.is_a?(Hash)
    return false if stored["expires_at"].to_i < now.to_i

    candidate = answer.to_s.gsub(/\s+/, "")
    return false unless candidate.match?(/\A\d{#{CODE_LENGTH}}\z/)

    ActiveSupport::SecurityUtils.secure_compare(stored["digest"].to_s, digest(candidate))
  end

  def digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", key, code.to_s)
  end

  def key
    Rails.application.key_generator.generate_key("ergocheck captcha")
  end
end
