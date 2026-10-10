class SessionsController < InertiaController
  allow_unauthenticated_access only: %i[new create]
  # Two independent limits: per client address, and per account so a distributed
  # guesser cannot hammer one admin from many addresses.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "by-ip", with: -> {
    redirect_to new_session_path, inertia: { errors: { base: [ "Too many attempts. Please wait a few minutes and try again." ] } }
  }
  rate_limit to: 6, within: 10.minutes, only: :create, name: "by-account", by: -> { params[:email].to_s.strip.downcase.first(254) }, with: -> {
    redirect_to new_session_path, inertia: { errors: { base: [ "Too many attempts. Please wait a few minutes and try again." ] } }
  }

  def new
    return redirect_to(root_path) if authenticated?

    render inertia: {}
  end

  def create
    # The CAPTCHA is checked (and consumed) before the credentials are looked at.
    unless Captcha.verify?(session, params[:captcha])
      return redirect_to new_session_path, inertia: { errors: { captcha: [ "That code didn't match. Please try the new image." ] } }
    end

    admin = authenticate_admin

    if admin
      start_new_session_for(admin)
      redirect_to after_authentication_url
    else
      # One generic message: never reveal whether the e-mail address exists.
      redirect_to new_session_path, inertia: { errors: { base: [ "We couldn't sign you in with those details." ] } }
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, inertia: { clear_history: true }
  end

  private

  def authenticate_admin
    email = params[:email].to_s
    password = params[:password].to_s
    return if email.blank? || password.blank?

    Admin.authenticate_by(email: email.strip.downcase, password: password)
  end
end
