class AddRevenueToAds < ActiveRecord::Migration[8.1]
  def change
    # What the PLATFORM measured, which it can only do when a pixel or a
    # conversions API is reporting purchases back to it. Nullable, and null is
    # the normal case for a business that takes orders on WhatsApp and over the
    # counter: nothing is watching, so nothing is measured. Null must never
    # become a zero, because "no purchases" and "nothing measured purchases"
    # are different statements about money.
    add_column :ad_metrics, :conversions, :bigint
    add_column :ad_metrics, :conversion_value_minor, :bigint

    add_check_constraint :ad_metrics,
      "conversions IS NULL OR conversions >= 0", name: "ad_metrics_conversions_is_not_negative"
    add_check_constraint :ad_metrics,
      "conversion_value_minor IS NULL OR conversion_value_minor >= 0",
      name: "ad_metrics_conversion_value_is_not_negative"

    # What the OWNER counted themselves.
    #
    # This exists because the honest answer for most Indian small businesses is
    # that no platform will ever report their revenue: the order arrives as a
    # WhatsApp message and the money arrives as UPI. The shopkeeper knows what
    # the campaign brought in; Prachar does not, and cannot.
    #
    # Kept in its own table, never merged with what a platform reported. Two
    # numbers of different provenance summed into one figure would be worth
    # less than either.
    create_table :ad_outcomes do |t|
      t.references :ad_campaign, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }

      t.date :occurred_on, null: false
      t.integer :orders
      t.bigint :revenue_minor
      t.string :currency, null: false, default: "INR"
      t.string :note

      t.timestamps
    end

    add_index :ad_outcomes, %i[ad_campaign_id occurred_on]

    add_check_constraint :ad_outcomes,
      "orders IS NULL OR orders >= 0", name: "ad_outcomes_orders_is_not_negative"
    add_check_constraint :ad_outcomes,
      "revenue_minor IS NULL OR revenue_minor >= 0", name: "ad_outcomes_revenue_is_not_negative"
    # A row that records neither is not a record of anything.
    add_check_constraint :ad_outcomes,
      "orders IS NOT NULL OR revenue_minor IS NOT NULL", name: "ad_outcomes_records_something"
  end
end
