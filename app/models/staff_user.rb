# A Prachar team member who curates the shared template gallery.
#
# Entirely separate from User. There is no association between the two and no
# way to promote one into the other, which is the point: publishing to every
# workspace's gallery is platform-wide power and must not sit behind a customer
# login.
class StaffUser < ApplicationRecord
  has_secure_password

  has_many :staff_sessions, dependent: :destroy
  has_many :published_templates, class_name: "Template", foreign_key: :published_by_id,
           dependent: :nullify, inverse_of: :published_by

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 120 }
  # Longer than the customer minimum: this account can change what every
  # business in the product sees.
  validates :password, length: { minimum: 16 }, allow_nil: true

  scope :active, -> { where(deactivated_at: nil) }

  def active? = deactivated_at.nil?

  def deactivate!
    transaction do
      update!(deactivated_at: Time.current)
      staff_sessions.update_all(revoked_at: Time.current)
    end
  end
end
