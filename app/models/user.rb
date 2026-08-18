class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :workspace_memberships, dependent: :nullify
  has_many :owned_workspaces, class_name: "Workspace", foreign_key: :owner_user_id, dependent: :restrict_with_error, inverse_of: :owner_user

  # Only accepted, active memberships grant access. Every workspace lookup in
  # the application goes through this association, never through a parameter.
  has_many :accepted_memberships,
    -> { accepted.active },
    class_name: "WorkspaceMembership",
    inverse_of: :user
  has_many :workspaces, through: :accepted_memberships

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :phone, with: ->(phone) { phone.presence && phone.gsub(/[^\d+]/, "") }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 120 }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :timezone, presence: true, inclusion: { in: -> (_) { ActiveSupport::TimeZone::MAPPING.values } }

  def confirmed?
    confirmed_at.present?
  end

  def member_of?(workspace)
    accepted_memberships.exists?(workspace: workspace)
  end
end
