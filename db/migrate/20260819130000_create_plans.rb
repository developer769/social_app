class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :tagline
      t.bigint :price_minor, null: false
      t.string :currency, null: false, default: "INR"
      t.string :interval, null: false, default: "month"
      t.integer :trial_days, null: false, default: 14
      t.boolean :recommended, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :plans, %i[code interval], unique: true
    add_index :plans, %i[active position]

    add_check_constraint :plans, "price_minor >= 0", name: "plans_price_not_negative"
    add_check_constraint :plans, "interval IN ('month','year')", name: "plans_interval_is_known"
    add_check_constraint :plans, "char_length(currency) = 3", name: "plans_currency_is_iso4217"

    # Limits are data, not conditionals scattered through the code. Nothing
    # anywhere asks "is this the pro plan?" -- it asks what the entitlement is
    # (spec 22: use a centralised entitlement system).
    create_table :plan_entitlements do |t|
      t.references :plan, null: false, foreign_key: true
      t.string :key, null: false
      # NULL means unlimited, which is different from zero.
      t.integer :limit_value
      t.string :display_label, null: false

      t.timestamps
    end

    add_index :plan_entitlements, %i[plan_id key], unique: true
  end
end
