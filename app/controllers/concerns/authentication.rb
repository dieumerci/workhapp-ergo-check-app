# Cookie + server-side session authentication for company admins.
#
# The encrypted, HttpOnly session cookie holds only a random token. The server
# keeps its digest in an AdminSession row, which is what makes the session
# revocable (sign-out deletes the row, so a copied cookie stops working) and lets
# the server decide when it has been idle too long. The cookie is reset on sign-in
# (no fixation) and on sign-out.
module Authentication
  extend ActiveSupport::Concern

  IDLE_TIMEOUT = AdminSession::IDLE_TIMEOUT
  # Sent by the exports poller. A page left open in a background tab must not keep
  # a session alive forever, so these requests do not count as activity.
  BACKGROUND_HEADER = "X-Background-Poll".freeze

  included do
    before_action :require_authentication
    helper_method :authenticated? if respond_to?(:helper_method)
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.admin ||= admin_from_session
  end

  def admin_from_session
    token = session[:session_token]
    return if token.blank?

    record = AdminSession.includes(admin: :company).find_live(token)
    if record.nil?
      reset_session
      return
    end

    record.touch_if_stale unless background_request?
    Current.admin_session = record
    record.admin
  end

  def background_request?
    request.headers[BACKGROUND_HEADER].present?
  end

  def request_authentication
    session[:return_to] = request.fullpath if request.get? && !request.xhr?
    redirect_to new_session_path
  end

  def after_authentication_url
    session.delete(:return_to).presence || root_path
  end

  def start_new_session_for(admin)
    return_to = session[:return_to]
    reset_session
    session[:return_to] = return_to if return_to
    session[:session_token] = AdminSession.start(admin)
    Current.admin = admin
  end

  def terminate_session
    AdminSession.revoke(session[:session_token])
    reset_session
    Current.reset
  end
end
