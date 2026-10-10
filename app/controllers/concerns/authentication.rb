# Cookie-session authentication for company admins.
#
# The session cookie (encrypted and HttpOnly, see config/initializers/session_store.rb)
# holds only the admin id and a last-seen timestamp. The session is reset on
# sign-in (prevents fixation) and on sign-out, and expires after being idle.
module Authentication
  extend ActiveSupport::Concern

  IDLE_TIMEOUT = 8.hours

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
    admin_id = session[:admin_id]
    return if admin_id.blank?

    if session_idle?
      reset_session
      return
    end

    admin = Admin.includes(:company).find_by(id: admin_id)
    session[:last_seen_at] = Time.current.to_i if admin
    admin
  end

  def session_idle?
    last_seen = session[:last_seen_at]
    last_seen.nil? || Time.zone.at(last_seen) < IDLE_TIMEOUT.ago
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
    session[:admin_id] = admin.id
    session[:last_seen_at] = Time.current.to_i
    Current.admin = admin
  end

  def terminate_session
    reset_session
    Current.reset
  end
end
