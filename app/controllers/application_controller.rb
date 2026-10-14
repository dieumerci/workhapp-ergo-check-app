class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Assessment data is health-related: never let a browser or proxy keep a copy.
  before_action { response.headers["Cache-Control"] = "no-store" }

  # Another company's record and a record that never existed get the same plain 404 page. The reason goes to the
  # log (ids only), never to the response, so a 404 cannot be used to probe what exists.
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found(exception)
    logger.info("Not found: #{exception.message}")
    respond_to do |format|
      format.html { render file: Rails.public_path.join("404.html"), layout: false, status: :not_found }
      format.any { head :not_found }
    end
  end

  def cookie_preferences
    @cookie_preferences ||= CookiePreferences.new(cookies, secure: request.ssl?)
  end
end
