class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.references :plan, null: false, foreign_key: true
      t.references :selected_by, foreign_key: { to_table: :users }

      t.string :status, null: false, default: "trialing"
      t.datetime :trial_ends_at
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at

      # No payment provider is contracted yet, so these stay null until one is.
      t.string :provider
      t.string :provider_subscription_id

      t.timestamps
    end

    add_check_constraint :subscriptions,
      "status IN ('trialing','active','past_due','cancelled','expired')",
      name: "subscriptions_status_is_known"
  end
end
