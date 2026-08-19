class CreateSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_accounts do |t|
      t.references :workspace, null: false, foreign_key: true

      t.string :provider, null: false
      t.string :external_account_id, null: false
      t.string :username
      t.string :display_name
      t.string :avatar_url

      t.string :connection_status, null: false, default: "connected"
      t.string :permission_status, null: false, default: "granted"
      t.string :granted_scopes, array: true, null: false, default: []
      t.string :missing_scopes, array: true, null: false, default: []

      t.datetime :token_expires_at
      t.datetime :last_synced_at
      t.references :connected_by, foreign_key: { to_table: :users }
      t.datetime :connected_at
      t.datetime :disconnected_at

      t.timestamps
    end

    # One workspace cannot connect the same provider account twice, but two
    # different workspaces may legitimately connect the same account.
    add_index :social_accounts, %i[workspace_id provider external_account_id],
      unique: true, name: "index_social_accounts_on_workspace_provider_account"
    add_index :social_accounts, %i[workspace_id connection_status]

    add_check_constraint :social_accounts,
      "provider IN ('instagram','facebook','linkedin','youtube','tiktok','google_business','x')",
      name: "social_accounts_provider_is_known"
    add_check_constraint :social_accounts,
      "connection_status IN ('connected','disconnected','expired','revoked','error')",
      name: "social_accounts_connection_status_is_known"
    add_check_constraint :social_accounts,
      "permission_status IN ('granted','partial','denied')",
      name: "social_accounts_permission_status_is_known"
  end
end
