# The app's cookie policy, in one place.
#
#   _ergocheck_session  strictly necessary  keeps you signed in (session cookie)
#   XSRF-TOKEN          strictly necessary  CSRF protection for in-page requests
#   ergocheck_consent   strictly necessary  remembers the choice made here (12 months)
#   ergocheck_prefs     optional            remembers the dashboard status filter and
#                                           date preset (90 days), only with consent
#
# Everything optional is gated on #preferences_allowed?. Both cookies written
# here are signed (tamper-evident), HttpOnly and SameSite=Lax; values read back
# are validated against a whitelist, so a forged cookie can never inject input.
class CookiePreferences
  CONSENT_COOKIE = :ergocheck_consent
  PREFS_COOKIE = :ergocheck_prefs
  CONSENT_TTL = 12.months
  PREFS_TTL = 90.days
  PRESETS = %w[7 30 90 all].freeze
  STATUS_CHOICES = (Status::CANONICAL + [ "all" ]).freeze

  def initialize(jar, secure: false)
    @jar = jar
    @secure = secure
  end

  def decided?
    consent.present?
  end

  def preferences_allowed?
    consent.present? && consent["preferences"] == true
  end

  # Stores the visitor's choice. Declining also removes anything optional that
  # was stored earlier.
  def record_consent(preferences:)
    write(CONSENT_COOKIE, { "v" => 1, "preferences" => preferences ? true : false }, CONSENT_TTL)
    forget_preferences unless preferences
  end

  # Remembers dashboard defaults, but only when the visitor opted in.
  def remember_filters(status:, preset:)
    return unless preferences_allowed?
    return unless STATUS_CHOICES.include?(status) && PRESETS.include?(preset)

    write(PREFS_COOKIE, { "status" => status, "preset" => preset }, PREFS_TTL)
  end

  # { status:, preset: } when a valid remembered choice exists, otherwise {}.
  def remembered_filters
    return {} unless preferences_allowed?

    stored = @jar.signed[PREFS_COOKIE]
    return {} unless stored.is_a?(Hash)

    status = stored["status"]
    preset = stored["preset"]
    return {} unless STATUS_CHOICES.include?(status) && PRESETS.include?(preset)

    { status: status, preset: preset }
  end

  def forget_preferences
    @jar.delete(PREFS_COOKIE)
  end

  private

  def consent
    value = @jar.signed[CONSENT_COOKIE]
    value.is_a?(Hash) && value["v"] == 1 ? value : nil
  end

  def write(name, value, ttl)
    @jar.signed[name] = {
      value: value,
      expires: ttl.from_now,
      httponly: true,
      same_site: :lax,
      secure: @secure
    }
  end
end
