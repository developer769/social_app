class CreateStaffUsers < ActiveRecord::Migration[8.1]
  def change
    # Deliberately NOT a flag on users.
    #
    # A staff account can publish to every workspace's gallery, so it holds
    # platform-wide power. Keeping it in its own table with its own sessions
    # means a compromised customer account has no path to it at all: there is
    # no column to flip, and the two authentication paths share no cookie, no
    # controller and no session store.
    create_table :staff_users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.datetime :last_seen_at
      t.datetime :deactivated_at

      t.timestamps
    end

    add_index :staff_users, :email, unique: true

    create_table :staff_sessions do |t|
      t.references :staff_user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :staff_sessions, :token_digest, unique: true
    add_index :staff_sessions, %i[staff_user_id revoked_at]

    # Who published or changed a template, kept separate from the customer
    # audit trail because the actor is a different kind of person entirely.
    create_table :staff_audit_events do |t|
      t.references :staff_user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address
      t.datetime :created_at, null: false
    end

    add_index :staff_audit_events, :created_at, order: { created_at: :desc }
    add_index :staff_audit_events, %i[auditable_type auditable_id]

    # Templates gain the file itself. Until now only a preview image existed,
    # which is enough to browse a catalogue but not to generate from one.
    add_column :templates, :published_at, :datetime
    add_reference :templates, :published_by, foreign_key: { to_table: :staff_users }
    add_column :templates, :draft, :boolean, null: false, default: false
    add_index :templates, %i[draft active retired_at]
  end
end
