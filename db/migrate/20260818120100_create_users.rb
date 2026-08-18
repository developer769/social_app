class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      # Nullable: the design screens lead with "Continue with Phone", but phone
      # sign-in needs an SMS provider, so email is the first supported strategy
      # and this column is ready for the second.
      t.string :phone
      t.datetime :confirmed_at
      t.string :timezone, null: false, default: "Asia/Kolkata"
      t.string :locale, null: false, default: "en"
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :phone, unique: true, where: "phone IS NOT NULL"
  end
end
