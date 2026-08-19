class Subscription < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[trialing active past_due cancelled expired].freeze

  belongs_to :plan
  belongs_to :selected_by, class_name: "User", optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  def trialing_now?
    trialing? && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_days_remaining
    return 0 if trial_ends_at.blank?

    [ ((trial_ends_at - Time.current) / 1.day).ceil, 0 ].max
  end

  # The single question the rest of the application asks about limits.
  def limit_for(key) = plan.limit_for(key)
  def unlimited?(key) = plan.unlimited?(key)

  def allows?(key, current_count)
    return false unless active? || trialing_now?
    return true if unlimited?(key)

    limit = limit_for(key)
    limit.nil? ? true : current_count < limit
  end
end
