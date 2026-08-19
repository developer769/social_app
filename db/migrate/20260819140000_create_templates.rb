class CreateTemplates < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, not workspace-owned: templates are curated and refreshed centrally
    # and every workspace sees the same catalogue. Nothing workspace-specific
    # may ever be stored here, which is why there is no workspace_id.
    create_table :templates do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description

      t.string :media_format, null: false          # image | video
      t.string :content_category, null: false      # festive | offer | ...
      t.string :aspect_ratio, null: false, default: "1:1"
      t.integer :duration_seconds                  # video only
      t.string :industry
      t.string :style_tags, array: true, null: false, default: []
      t.string :supported_platforms, array: true, null: false, default: []

      # What the generator is actually told. Never shown raw to the owner.
      t.text :prompt_instructions
      t.integer :prompt_version, null: false, default: 1

      t.boolean :premium, null: false, default: false
      t.boolean :active, null: false, default: true

      # ---- Where this template came from, and how long it stays -------------
      # The catalogue refreshes, so a template has a provenance and a lifecycle
      # rather than being a fixture that lives forever.
      t.string :source, null: false, default: "curated"
      t.string :source_external_id
      t.datetime :first_seen_at, null: false
      t.datetime :last_refreshed_at
      t.datetime :retired_at

      # Populated only by a source that supplies a real popularity signal. Null
      # means "we have no trend data for this", which is why ordering must not
      # silently treat it as zero.
      t.integer :trend_score
      t.datetime :trend_scored_at

      # Real usage inside Prachar, counted from our own records.
      t.integer :generations_count, null: false, default: 0
      t.integer :favourites_count, null: false, default: 0

      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :templates, :slug, unique: true
    add_index :templates, %i[source source_external_id], unique: true,
      where: "source_external_id IS NOT NULL", name: "index_templates_on_source_and_external_id"
    add_index :templates, %i[media_format active retired_at]
    add_index :templates, %i[content_category active]
    add_index :templates, :trend_score, order: { trend_score: :desc }
    add_index :templates, :style_tags, using: :gin

    add_check_constraint :templates, "media_format IN ('image','video')",
      name: "templates_media_format_is_known"
    add_check_constraint :templates,
      "content_category IN ('festive','offer','new_launch','behind_the_scenes','product_showcase','reels_style','menu','tips','educational','testimonials')",
      name: "templates_content_category_is_known"
    add_check_constraint :templates, "source IN ('curated','trend_feed','partner')",
      name: "templates_source_is_known"
    # A video template without a duration cannot be validated against a
    # platform's video limits, so it is refused at the database.
    add_check_constraint :templates,
      "media_format <> 'video' OR duration_seconds IS NOT NULL",
      name: "templates_video_has_duration"
    add_check_constraint :templates,
      "duration_seconds IS NULL OR duration_seconds > 0",
      name: "templates_duration_positive"
    add_check_constraint :templates,
      "trend_score IS NULL OR trend_score BETWEEN 0 AND 100",
      name: "templates_trend_score_in_range"

    # WORKSPACE-OWNED. Kept separate from the global table so a workspace's
    # interest in a template can never be written onto the shared record.
    create_table :template_favourites do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :template_favourites, %i[workspace_id template_id], unique: true

    # An audit of each refresh, so "why did that template disappear" has an
    # answer, and so a broken feed is visible rather than silent.
    create_table :template_refreshes do |t|
      t.string :source, null: false
      t.string :status, null: false, default: "running"
      t.integer :added_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :retired_count, null: false, default: 0
      t.string :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end

    add_index :template_refreshes, %i[source started_at], order: { started_at: :desc }
    add_check_constraint :template_refreshes,
      "status IN ('running','complete','failed')",
      name: "template_refreshes_status_is_known"
  end
end
