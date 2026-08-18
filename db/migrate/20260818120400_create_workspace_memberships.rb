class CreateWorkspaceMemberships < ActiveRecord::Migration[8.1]
  def change
    # Deliberately has NO role or permission column. The specification defers
    # roles entirely (spec 2, 8): accepted members get identical access, and a
    # role can be introduced later without reshaping this table.
    create_table :workspace_memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      # Null until an invitation is accepted; the invitee may not have an
      # account yet.
      t.references :user, foreign_key: true

      t.citext :invitation_email
      t.string :invitation_token_digest
      t.string :invitation_status, null: false, default: "pending"
      t.string :membership_status, null: false, default: "active"

      t.references :invited_by, foreign_key: { to_table: :users }
      t.datetime :invited_at
      t.datetime :accepted_at
      t.datetime :declined_at
      t.datetime :removed_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :workspace_memberships, :invitation_token_digest, unique: true
    add_index :workspace_memberships, [ :workspace_id, :user_id ],
      unique: true, where: "user_id IS NOT NULL",
      name: "index_memberships_on_workspace_and_user"
    # Only one live invitation per email per workspace; declined or cancelled
    # invitations can be reissued.
    add_index :workspace_memberships, [ :workspace_id, :invitation_email ],
      unique: true, where: "invitation_status = 'pending'",
      name: "index_memberships_on_workspace_and_pending_email"

    add_check_constraint :workspace_memberships,
      "user_id IS NOT NULL OR invitation_email IS NOT NULL",
      name: "memberships_identify_a_person"
    add_check_constraint :workspace_memberships,
      "invitation_status IN ('pending','accepted','declined','expired','cancelled')",
      name: "memberships_invitation_status_is_known"
    add_check_constraint :workspace_memberships,
      "membership_status IN ('active','inactive','removed')",
      name: "memberships_membership_status_is_known"
    # An accepted invitation must have a user attached, or the row claims access
    # for nobody.
    add_check_constraint :workspace_memberships,
      "invitation_status <> 'accepted' OR user_id IS NOT NULL",
      name: "memberships_accepted_requires_user"
  end
end
