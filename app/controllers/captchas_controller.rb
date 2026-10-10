# Serves a fresh CAPTCHA image and remembers its digest in the session.
class CaptchasController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 40, within: 1.minute, only: :show, with: -> { head :too_many_requests }

  def show
    code = Captcha.issue(session)
    send_data Captcha::Renderer.png(code), type: "image/png", disposition: "inline"
  end
end
