class CreateBrandProfiles < ActiveRecord::Migration[8.1]
  def change
    # The business name, timezone, currency and locale live on Workspace and are
    # not duplicated here; this table holds the descriptive brand context that
    # content generation reads from.
    create_table :brand_profiles do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }

      t.string :category
      t.string :business_type
      t.string :contact_email
      t.string :phone
      t.string :website_url
      t.string :city
      t.text :about

      t.timestamps
    end

    add_check_constraint :brand_profiles,
      "about IS NULL OR char_length(about) <= 500",
      name: "brand_profiles_about_within_limit"
    add_check_constraint :brand_profiles,
      "business_type IS NULL OR business_type IN ('sole_proprietor','small_business','partnership','private_limited','llp','other')",
      name: "brand_profiles_business_type_is_known"
  end
end
