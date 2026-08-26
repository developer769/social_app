# One request to get back into an account.
#
# The token lives only in the email. What is stored is its digest, so a leaked
# database hands over no working links (spec 13, 32).
class PasswordReset < ApplicationRecord
  # Short on purpose. A reset link is a live credential sitting in an inbox,
  # and an inbox is not a safe place to leave one for a week.
  VALID_FOR = 2.hours

  # Enough to stop somebody filling a person's inbox, loose enough that a
  # request lost to spam can be tried again.
  MAX_PER_HOUR = 5

  belongs_to :user

  attr_reader :raw_token

  scope :usable, -> { where(used_at: nil).where(expires_at: Time.current..) }
  scope :recent, -> { where(created_at: 1.hour.ago..) }

  def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw.to_s)

  def self.find_usable(raw)
    return if raw.blank?

    usable.find_by(token_digest: digest(raw))
  end

  # Answers the same way whether or not the address has an account, so this
  # cannot be used to find out who is registered.
  def self.issue!(user:, ip: nil)
    return if user.blank?
    return if where(user: user).recent.count >= MAX_PER_HOUR

    raw = SecureRandom.urlsafe_base64(32)
    reset = create!(user: user, token_digest: digest(raw),
                    expires_at: VALID_FOR.from_now, requested_ip: ip)
    reset.instance_variable_set(:@raw_token, raw)
    reset
  end

  def usable? = used_at.nil? && expires_at > Time.current

  # Single use, and every OTHER outstanding request for the same person is
  # spent at the same moment: asking twice and using the first link must not
  # leave the second one live in an inbox.
  def consume!(ip: nil)
    transaction do
      update!(used_at: Time.current, used_ip: ip)
      self.class.where(user_id: user_id).usable.update_all(used_at: Time.current)
    end
  end
end
