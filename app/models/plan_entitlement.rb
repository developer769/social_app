class PlanEntitlement < ApplicationRecord
  belongs_to :plan

  validates :key, presence: true, inclusion: { in: Plan::ENTITLEMENT_KEYS },
                  uniqueness: { scope: :plan_id }
  validates :display_label, presence: true
  validates :limit_value, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

  def unlimited? = limit_value.nil?
end
