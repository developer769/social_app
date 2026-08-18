class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :workspace, null: false, foreign_key: true

      t.string :name, null: false
      t.string :category
      t.bigint :starting_price_minor
      t.string :currency, null: false, default: "INR"
      # The designs express duration as a range of days ("2-3 days", "1 day"),
      # not minutes, so it is stored as two integers and formatted for display.
      t.integer :duration_min_days
      t.integer :duration_max_days
      t.text :description
      t.string :booking_url
      t.string :availability_status, null: false, default: "available"
      t.boolean :featured, null: false, default: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :services, [ :workspace_id, :position ]
    add_index :services, [ :workspace_id, :featured ]

    add_check_constraint :services,
      "starting_price_minor IS NULL OR starting_price_minor >= 0",
      name: "services_price_not_negative"
    add_check_constraint :services, "char_length(currency) = 3", name: "services_currency_is_iso4217"
    add_check_constraint :services,
      "description IS NULL OR char_length(description) <= 200",
      name: "services_description_within_limit"
    add_check_constraint :services,
      "availability_status IN ('available','unavailable','coming_soon')",
      name: "services_availability_is_known"
    add_check_constraint :services,
      "duration_min_days IS NULL OR duration_min_days > 0",
      name: "services_duration_min_positive"
    add_check_constraint :services,
      "duration_max_days IS NULL OR duration_min_days IS NULL OR duration_max_days >= duration_min_days",
      name: "services_duration_range_is_ordered"
  end
end
