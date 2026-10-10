# Records the visitor's cookie choice. Reachable before sign-in so the banner
# works on the sign-in page too.
class CookieConsentsController < ApplicationController
  allow_unauthenticated_access only: :create

  def create
    # Consent is opt-in: only the literal "true" grants it, never a loosely cast value.
    preferences = params[:preferences].to_s == "true"
    cookie_preferences.record_consent(preferences: preferences)

    redirect_back_or_to root_path
  end
end
