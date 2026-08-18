class Session < ApplicationRecord
  DURATION = 30.days

  belongs_to :user

  # The raw token is returned once, at creation, and never stored. Only its
  # digest is persisted, so a database leak does not hand over live sessions.
  attr_reader :raw_token

  scope :active, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

  def self.start!(user:, ip_address: nil, user_agent: nil)
    raw_token = SecureRandom.urlsafe_base64(32)

    session = create!(
      user: user,
      token_digest: digest(raw_token),
      ip_address: ip_address,
      user_agent: user_agent,
      expires_at: DURATION.from_now
    )
    session.instance_variable_set(:@raw_token, raw_token)
    session
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def self.digest(raw_token)
    OpenSSL::Digest::SHA256.hexdigest(raw_token)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end
end
