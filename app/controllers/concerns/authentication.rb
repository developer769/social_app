module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :prachar_session
  RETURN_TO_KEY = :return_to_after_authenticating

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
    # HEAD is routed like GET but request.get? is false for it, so both are
    # checked; otherwise the return-to path is silently dropped.
    #
    # Only the path is stored, never the full URL: a value that carries a host
    # is one bug away from redirecting a freshly authenticated user off-site.
    store_return_to(request.fullpath) if request.get? || request.head?
    redirect_to login_path
  end

  def store_return_to(path)
    session[RETURN_TO_KEY] = path if local_path?(path)
  end

  # Accepts only a single-slash absolute path. Rejects "//evil.test" and
  # "/\evil.test", which browsers treat as protocol-relative URLs, and anything
  # carrying a scheme.
  def local_path?(path)
    path.is_a?(String) &&
      path.start_with?("/") &&
      !path.start_with?("//", "/\\") &&
      !path.match?(%r{\A/*[a-z][a-z0-9+.-]*:}i)
  end

  def start_new_session_for(user)
    # Everything written to the session before authentication is discarded, so
    # a session id planted on the browser beforehand cannot survive the
    # privilege change. The return-to path is deliberately carried across,
    # having already been validated as local.
    return_to = session[RETURN_TO_KEY]
    reset_session
    session[RETURN_TO_KEY] = return_to if return_to.present?

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
    # Clears any return-to path and flash left over from the signed-in user, so
    # a shared machine hands nothing to the next person.
    reset_session
  end

  def after_authentication_url
    stored = session.delete(RETURN_TO_KEY)
    return stored if local_path?(stored)

    default_post_authentication_url
  end

  # Straight into the workspace when there is exactly one, otherwise the picker.
  def default_post_authentication_url
    return root_path if Current.user.nil?

    Workspaces::LandingPath.new(user: Current.user).call
  end
end
