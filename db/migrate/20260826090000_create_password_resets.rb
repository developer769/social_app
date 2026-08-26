class CreatePasswordResets < ActiveRecord::Migration[8.1]
  def change
    # One request to get back in.
    #
    # There was no way to do this at all: somebody who forgot their password
    # was locked out of their own business permanently, with no route, no
    # mailer and no link on the sign-in page.
    #
    # The token is stored as a digest, never in the clear, exactly as
    # invitations are -- a leaked database must not hand over working reset
    # links.
    create_table :password_resets do |t|
      t.references :user, null: false, foreign_key: true

      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      # Kept for the audit trail: a burst of requests for one account from one
      # address is worth being able to see afterwards.
      t.string :requested_ip
      t.string :used_ip

      t.timestamps
    end

    add_index :password_resets, :token_digest, unique: true
    add_index :password_resets, %i[user_id created_at]
  end
end
