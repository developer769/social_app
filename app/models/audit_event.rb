class AuditEvent < ApplicationRecord
  belongs_to :workspace, optional: true
  belongs_to :actor_user, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # Audit rows are append-only. Rails raises ActiveRecord::ReadOnlyRecord on any
  # attempt to update a persisted row.
  def readonly?
    persisted?
  end

  def self.record!(action:, workspace: nil, actor_user: nil, auditable: nil, metadata: {}, ip_address: nil)
    create!(
      action: action,
      workspace: workspace,
      actor_user: actor_user,
      auditable: auditable,
      metadata: metadata,
      ip_address: ip_address
    )
  end
end
