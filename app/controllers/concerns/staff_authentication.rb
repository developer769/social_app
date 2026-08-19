module StaffAuthentication
  extend ActiveSupport::Concern

  # A different cookie name and a different table from the customer session, so
  # holding one grants nothing towards the other. There is deliberately no code
  # path that turns a User into a StaffUser.
  STAFF_COOKIE = :prachar_staff_session

  included do
    before_action :require_staff_authentication
    helper_method :current_staff_user, :staff_signed_in?
  end

  class_methods do
    def allow_unauthenticated_staff_access(**options)
      skip_before_action :require_staff_authentication, **options
    end
  end

  private

  def current_staff_user = @current_staff_session&.staff_user

  def staff_signed_in? = @current_staff_session.present?

  def require_staff_authentication
    resume_staff_session || redirect_to(admin_login_path)
  end

  def resume_staff_session
    return @current_staff_session if @current_staff_session

    session_record = StaffSession.authenticate(cookies.signed[STAFF_COOKIE])
    return if session_record.blank?

    @current_staff_session = session_record
  end

  def start_staff_session_for(staff_user)
    reset_session

    session_record = StaffSession.start!(
      staff_user: staff_user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.signed[STAFF_COOKIE] = {
      value: session_record.raw_token,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?,
      # Session cookie, not permanent: platform-wide access should not persist
      # on a closed browser.
      expires: StaffSession::DURATION.from_now
    }

    @current_staff_session = session_record
  end

  def terminate_staff_session
    @current_staff_session&.revoke!
    cookies.delete(STAFF_COOKIE)
    @current_staff_session = nil
    reset_session
  end

  def record_staff_event(action, auditable: nil, metadata: {})
    StaffAuditEvent.record!(
      action: action, staff_user: current_staff_user, auditable: auditable,
      metadata: metadata, ip_address: request.remote_ip
    )
  end
end
