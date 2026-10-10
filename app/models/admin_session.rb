# One signed-in browser. The session cookie carries a random token; only its
# digest is stored here, so a database leak cannot be replayed as a login.
# Because the row lives on the server it can be revoked (sign-out deletes it)
# and expires on the server's clock.
class AdminSession < ApplicationRecord
  IDLE_TIMEOUT = 8.hours
  # Writing last_seen_at on every request would be a write per click; once a
  # minute is precise enough for an 8-hour window.
  TOUCH_EVERY = 1.minute

  belongs_to :admin

  scope :live, -> { where(last_seen_at: IDLE_TIMEOUT.ago..) }

  class << self
    # Creates a session and returns the raw token (shown once, never stored).
    def start(admin)
      purge_idle
      token = SecureRandom.urlsafe_base64(32)
      create!(admin: admin, token_digest: digest(token), last_seen_at: Time.current)
      token
    end

    def find_live(token)
      return if token.blank?

      live.find_by(token_digest: digest(token.to_s))
    end

    def revoke(token)
      where(token_digest: digest(token.to_s)).delete_all if token.present?
    end

    def purge_idle
      where(last_seen_at: ...(IDLE_TIMEOUT.ago - 1.day)).delete_all
    end

    def digest(token)
      Digest::SHA256.hexdigest(token)
    end
  end

  def touch_if_stale
    update_column(:last_seen_at, Time.current) if last_seen_at < TOUCH_EVERY.ago
  end
end
