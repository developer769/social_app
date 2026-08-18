class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    # A Workspace is the tenant. Currency, timezone and locale are columns with
    # India-first defaults rather than constants, so the domain logic never
    # hardcodes INR or IST (spec 3).
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :owner_user, null: false, foreign_key: { to_table: :users }

      t.string :currency, null: false, default: "INR"
      t.string :timezone, null: false, default: "Asia/Kolkata"
      t.string :locale, null: false, default: "en-IN"
      t.string :country_code, null: false, default: "IN"

      t.string :onboarding_step, null: false, default: "business_setup"
      t.datetime :onboarding_completed_at

      t.timestamps
    end

    add_index :workspaces, :slug, unique: true

    add_check_constraint :workspaces, "char_length(currency) = 3", name: "workspaces_currency_is_iso4217"
    add_check_constraint :workspaces, "slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'", name: "workspaces_slug_is_url_safe"
    add_check_constraint :workspaces,
      "onboarding_step IN ('business_setup','catalog','connections','analysis','health','plan','completed')",
      name: "workspaces_onboarding_step_is_known"
  end
end
