module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :prachar_session

  included do
    before_action :require_authentication
    helper_method :signed_in?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_user
    Current.user
  end

  def signed_in?
    Current.session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    return Current.session if Current.session

    session_record = Session.authenticate(cookies.signed[SESSION_COOKIE])
    return if session_record.blank?

    Current.session = session_record
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
    session_record
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url if request.get?
    redirect_to login_path
  end

  def start_new_session_for(user)
    session_record = Session.start!(
      user: user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.signed.permanent[SESSION_COOKIE] = {
      value: session_record.raw_token,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }

    Current.session = session_record
  end

  def terminate_session
    Current.session&.revoke!
    cookies.delete(SESSION_COOKIE)
    Current.session = nil
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_path
  end
end
