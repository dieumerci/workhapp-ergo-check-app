# The session cookie is the only cookie the app needs to work, so it is
# "strictly necessary" and not subject to the cookie-consent choice.
# Encrypted by Rails, invisible to JavaScript, never sent cross-site.
Rails.application.config.session_store :cookie_store,
  key: "_ergocheck_session",
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
