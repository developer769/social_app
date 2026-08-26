class CreateEmailVerifications < ActiveRecord::Migration[8.1]
  def change
    # Proof that somebody can read a given address.
    #
    # Covers both jobs, because they are the same job. Confirming the address
    # somebody signed up with and confirming the address they want to move to
    # differ only in what happens afterwards, and building them twice would
    # mean two token stores to keep safe.
    #
    # It matters because password reset goes to this address: an account whose
    # address was mistyped has no way back in at all, and until now nothing
    # ever checked.
    create_table :email_verifications do |t|
      t.references :user, null: false, foreign_key: true

      # The address being proved. For a signup that is the one already on the
      # account; for a change it is the new one, which is deliberately NOT
      # written to the user until it has been proved.
      t.string :email, null: false
      t.string :purpose, null: false

      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :requested_ip

      t.timestamps
    end

    add_index :email_verifications, :token_digest, unique: true
    add_index :email_verifications, %i[user_id purpose created_at]

    add_check_constraint :email_verifications,
      "purpose IN ('signup','change')", name: "email_verifications_purpose_is_known"
  end
end
