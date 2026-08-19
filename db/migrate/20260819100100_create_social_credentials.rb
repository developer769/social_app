class CreateSocialCredentials < ActiveRecord::Migration[8.1]
  def change
    # Tokens live in their own table so they are never loaded alongside the
    # account by default, and are encrypted at rest (spec 32).
    create_table :social_credentials do |t|
      t.references :social_account, null: false, foreign_key: true, index: { unique: true }

      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
