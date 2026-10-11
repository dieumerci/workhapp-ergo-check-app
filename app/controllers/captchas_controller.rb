# Serves a fresh CAPTCHA challenge and remembers its digest on the server.
class CaptchasController < ApplicationController
  allow_unauthenticated_access only: %i[show question]
  rate_limit to: 40, within: 1.minute, only: :show, name: "image", with: -> { head :too_many_requests }
  # The text alternative is easier to automate than the image, so ask for it sparingly.
  rate_limit to: 6, within: 1.hour, only: :question, name: "text-question", with: -> {
    render json: { error: "Too many requests. Please wait a while before asking for a text question." }, status: :too_many_requests
  }

  def show
    code = Captcha.issue(session)
    send_data Captcha::Renderer.png(code), type: "image/png", disposition: "inline"
  end

  # Accessible alternative for people who cannot read the image.
  def question
    render json: { question: Captcha.issue_text(session) }
  end
end
