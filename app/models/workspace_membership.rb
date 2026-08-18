class WorkspaceMembership < ApplicationRecord
  INVITATION_TTL = 14.days

  belongs_to :workspace
  belongs_to :user, optional: true
  belongs_to :invited_by, class_name: "User", optional: true

  enum :invitation_status,
    %w[pending accepted declined expired cancelled].index_by(&:itself),
    prefix: :invitation, validate: true

  enum :membership_status,
    %w[active inactive removed].index_by(&:itself),
    prefix: :membership, validate: true

  scope :accepted, -> { where(invitation_status: "accepted") }
  scope :active, -> { where(membership_status: "active") }
  scope :pending, -> { where(invitation_status: "pending") }

  normalizes :invitation_email, with: ->(email) { email.presence && email.strip.downcase }

  validates :invitation_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :identifies_a_person

  attr_reader :raw_invitation_token

  def self.digest(raw_token)
    OpenSSL::Digest::SHA256.hexdigest(raw_token)
  end

  def self.find_by_invitation_token(raw_token)
    return if raw_token.blank?

    find_by(invitation_token_digest: digest(raw_token))
  end

  # Explicit state transitions rather than assigning to the status attribute,
  # so every change has one auditable entry point (spec 10).
  def issue_invitation!(invited_by:)
    raw_token = SecureRandom.urlsafe_base64(32)

    update!(
      invitation_token_digest: self.class.digest(raw_token),
      invitation_status: "pending",
      invited_by: invited_by,
      invited_at: Time.current,
      expires_at: INVITATION_TTL.from_now
    )
    @raw_invitation_token = raw_token
    self
  end

  def accept_invitation!(user:)
    update!(
      user: user,
      invitation_status: "accepted",
      membership_status: "active",
      accepted_at: Time.current,
      invitation_token_digest: nil
    )
  end

  def decline_invitation!
    update!(invitation_status: "declined", declined_at: Time.current, invitation_token_digest: nil)
  end

  def cancel_invitation!
    update!(invitation_status: "cancelled", invitation_token_digest: nil)
  end

  def remove!
    update!(membership_status: "removed", removed_at: Time.current, invitation_token_digest: nil)
  end

  def invitation_expired?
    return false if expires_at.blank?

    invitation_pending? && expires_at <= Time.current
  end

  # The single question every authorization check asks.
  def grants_access?
    invitation_accepted? && membership_active?
  end

  private

  def identifies_a_person
    return if user_id.present? || invitation_email.present?

    errors.add(:base, "must have either a user or an invitation email")
  end
end
