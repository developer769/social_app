class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :workspace, null: false, foreign_key: true

      t.string :name, null: false
      t.string :category
      # Minor units (paise for INR) plus an explicit currency. Never a float,
      # and never an assumed INR.
      t.bigint :price_minor
      t.string :currency, null: false, default: "INR"
      t.boolean :price_is_starting_from, null: false, default: false
      t.text :description
      t.string :url
      t.string :availability_status, null: false, default: "available"
      t.string :stock_status, null: false, default: "in_stock"
      t.boolean :featured, null: false, default: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, [ :workspace_id, :position ]
    add_index :products, [ :workspace_id, :featured ]

    add_check_constraint :products, "price_minor IS NULL OR price_minor >= 0", name: "products_price_not_negative"
    add_check_constraint :products, "char_length(currency) = 3", name: "products_currency_is_iso4217"
    add_check_constraint :products,
      "description IS NULL OR char_length(description) <= 200",
      name: "products_description_within_limit"
    add_check_constraint :products,
      "availability_status IN ('available','unavailable','coming_soon')",
      name: "products_availability_is_known"
    add_check_constraint :products,
      "stock_status IN ('in_stock','low_stock','out_of_stock')",
      name: "products_stock_status_is_known"
  end
end
