class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # Append-only: no updated_at, because an audit row that can be edited is not
    # an audit row (spec 32).
    create_table :audit_events do |t|
      # Nullable so events that happen before a workspace exists (sign-up,
      # failed login) are still recorded.
      t.references :workspace, foreign_key: true
      t.references :actor_user, foreign_key: { to_table: :users }

      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address

      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :workspace_id, :created_at ], order: { created_at: :desc }
    add_index :audit_events, [ :auditable_type, :auditable_id ]
    add_index :audit_events, :action
  end
end
