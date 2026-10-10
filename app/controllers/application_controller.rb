class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Assessment data is health-related: never let a browser or proxy keep a copy.
  before_action { response.headers["Cache-Control"] = "no-store" }

  private

  def cookie_preferences
    @cookie_preferences ||= CookiePreferences.new(cookies, secure: request.ssl?)
  end
end
