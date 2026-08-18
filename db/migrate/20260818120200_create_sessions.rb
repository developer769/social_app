class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    # Sessions are rows rather than cookie-only so they can be listed and
    # revoked individually (spec 32: session revocation, Settings > Security).
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :sessions, :token_digest, unique: true
    add_index :sessions, [ :user_id, :revoked_at ]
  end
end
