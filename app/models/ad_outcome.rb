# What the owner counted themselves.
#
# The order arrived as a WhatsApp message and the money arrived as UPI, so no
# platform will ever report it. The shopkeeper knows what the campaign brought
# in; Prachar does not, and cannot. This is their record of it, kept apart from
# anything a platform said (see AdCampaign#return_on_spend).
class AdOutcome < ApplicationRecord
  belongs_to :ad_campaign
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :occurred_on, presence: true
  validates :orders, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                     allow_nil: true
  validates :revenue_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                            allow_nil: true
  validates :note, length: { maximum: 200 }, allow_blank: true
  validate :records_something
  validate :not_in_the_future

  scope :newest_first, -> { order(occurred_on: :desc, id: :desc) }

  def revenue = revenue_minor && Money.new(minor_units: revenue_minor, currency: currency)

  private

  def records_something
    return if orders.present? || revenue_minor.present?

    errors.add(:base, "Enter how many orders came in, how much they were worth, or both")
  end

  def not_in_the_future
    return if occurred_on.blank? || occurred_on <= Date.current

    errors.add(:occurred_on, "cannot be in the future")
  end
end
