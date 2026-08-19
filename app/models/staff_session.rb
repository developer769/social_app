class StaffSession < ApplicationRecord
  # Shorter than a customer session. Platform-wide access should not sit
  # unattended on a laptop for a month.
  DURATION = 12.hours

  belongs_to :staff_user

  attr_reader :raw_token

  scope :active, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

  def self.digest(raw_token) = OpenSSL::Digest::SHA256.hexdigest(raw_token)

  def self.start!(staff_user:, ip_address: nil, user_agent: nil)
    raw_token = SecureRandom.urlsafe_base64(32)

    session = create!(
      staff_user: staff_user, token_digest: digest(raw_token),
      ip_address: ip_address, user_agent: user_agent, expires_at: DURATION.from_now
    )
    session.instance_variable_set(:@raw_token, raw_token)
    session
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.joins(:staff_user).where(staff_users: { deactivated_at: nil })
          .find_by(token_digest: digest(raw_token))
  end

  def revoke! = update!(revoked_at: Time.current)
end
