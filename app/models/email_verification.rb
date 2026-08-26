# Proof that somebody can read a given address.
#
# The token lives only in the email; what is stored is its digest, as with
# password resets and invitations. A leaked database hands over no working
# links.
class EmailVerification < ApplicationRecord
  PURPOSES = %w[signup change].freeze

  # Longer than a password reset. This is not a credential somebody is waiting
  # on with a locked-out account -- it is a link that may sit unread until the
  # evening, and expiring it in two hours would mostly produce dead links.
  VALID_FOR = 3.days

  MAX_PER_HOUR = 5

  belongs_to :user

  enum :purpose, PURPOSES.index_by(&:itself), prefix: :for, validate: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  attr_reader :raw_token

  scope :usable, -> { where(used_at: nil).where(expires_at: Time.current..) }
  scope :recent, -> { where(created_at: 1.hour.ago..) }

  def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw.to_s)

  def self.find_usable(raw)
    return if raw.blank?

    usable.find_by(token_digest: digest(raw))
  end

  def self.issue!(user:, email:, purpose:, ip: nil)
    return if user.blank? || email.blank?
    return if where(user: user).recent.count >= MAX_PER_HOUR

    raw = SecureRandom.urlsafe_base64(32)
    record = create!(user: user, email: email.to_s.strip.downcase, purpose: purpose,
                     token_digest: digest(raw), expires_at: VALID_FOR.from_now,
                     requested_ip: ip)
    record.instance_variable_set(:@raw_token, raw)
    record
  end

  def usable? = used_at.nil? && expires_at > Time.current

  # Confirming a signup marks the account. Confirming a change moves the
  # address, which is why the new one was never written to the user until now:
  # an unproved address on the account would be a way to take it over, since
  # password reset goes wherever the address points.
  def confirm!
    return false unless usable?

    transaction do
      previous = user.email

      if for_change?
        user.update!(email: email, confirmed_at: Time.current)
      else
        user.update!(confirmed_at: Time.current)
      end

      # Every other outstanding link for this person is spent, so an older
      # change request cannot be used afterwards to move the address again.
      update!(used_at: Time.current)
      self.class.where(user_id: user_id).usable.update_all(used_at: Time.current)

      @previous_email = previous
    end

    true
  end

  attr_reader :previous_email
end
