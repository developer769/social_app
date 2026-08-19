class StaffAuditEvent < ApplicationRecord
  belongs_to :staff_user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def readonly? = persisted?

  def self.record!(action:, staff_user: nil, auditable: nil, metadata: {}, ip_address: nil)
    create!(action: action, staff_user: staff_user, auditable: auditable,
            metadata: metadata, ip_address: ip_address)
  end
end
