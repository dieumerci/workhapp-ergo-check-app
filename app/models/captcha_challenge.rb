# The server-side half of a CAPTCHA: the HMAC digest of the code and when it
# expires. The browser's session holds only this row's id, so a challenge can be
# consumed exactly once no matter how many times a cookie is replayed.
class CaptchaChallenge < ApplicationRecord
  TTL = 5.minutes

  class << self
    def issue(digest, now: Time.current)
      purge_expired(now)
      create!(digest: digest, expires_at: now + TTL)
    end

    # Returns the challenge's digest if it was valid, and deletes it either way.
    #
    # The DELETE is the gate: only one caller can remove a given row, so only one
    # caller can ever succeed, however many requests carry the same id at once.
    # (Do not "simplify" this into one DELETE ... RETURNING run through
    # select_one: that is a read path, and the query cache can answer a repeated
    # identical statement without executing it, which silently turns a
    # single-use token into a reusable one.)
    def consume(id, now: Time.current)
      return unless id.to_s.match?(/\A\d{1,18}\z/)

      row = where(id: id.to_i).pick(:digest, :expires_at) # may be cached; the delete below decides
      return unless row
      return unless where(id: id.to_i).delete_all == 1

      digest, expires_at = row
      digest if expires_at >= now
    end

    def discard(id)
      where(id: id).delete_all if id.to_s.match?(/\A\d{1,18}\z/)
    end

    def purge_expired(now = Time.current)
      where(expires_at: ...(now - 1.hour)).delete_all
    end
  end
end
