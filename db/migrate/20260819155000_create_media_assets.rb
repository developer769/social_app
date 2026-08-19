class CreateMediaAssets < ActiveRecord::Migration[8.1]
  def change
    # Every image or video a workspace uses in a post, whether uploaded by the
    # owner or produced by the generator later.
    create_table :media_assets do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :uploaded_by, foreign_key: { to_table: :users }

      t.string :kind, null: false                 # image | video
      t.string :origin, null: false, default: "upload"  # upload | generated
      t.integer :width
      t.integer :height
      t.integer :duration_ms
      t.bigint :byte_size
      t.string :content_type
      t.string :checksum
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :media_assets, %i[workspace_id created_at], order: { created_at: :desc }
    add_index :media_assets, %i[workspace_id checksum]

    add_check_constraint :media_assets, "kind IN ('image','video')", name: "media_assets_kind_is_known"
    add_check_constraint :media_assets, "origin IN ('upload','generated')", name: "media_assets_origin_is_known"
  end
end
