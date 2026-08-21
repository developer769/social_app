class CreateCreativeRequests < ActiveRecord::Migration[8.1]
  def change
    # One attempt to produce a creative for a post.
    #
    # Rows for every requested variant are created up front, exactly as
    # BrandAnalysisTask does, so progress is countable from real records rather
    # than animated (spec 24: do not fake generation progress).
    create_table :creative_requests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :post, foreign_key: true
      t.references :template, foreign_key: true
      t.references :requested_by, foreign_key: { to_table: :users }
      t.references :subject, polymorphic: true

      t.string :status, null: false, default: "queued"
      t.string :media_format, null: false, default: "image"
      t.integer :variant_count, null: false, default: 3

      # What the owner asked for, in their words. Steers the scene only, and is
      # never rendered onto the picture -- that would be the text-on-image
      # editor this product excludes (spec 2).
      t.string :instructions
      t.integer :prompt_version, null: false, default: 1
      t.string :provider, null: false, default: "mock"

      t.string :error_code
      t.string :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :creative_requests, %i[workspace_id created_at], order: { created_at: :desc }
    add_index :creative_requests, %i[status created_at]

    add_check_constraint :creative_requests,
      "status IN ('queued','generating','ready','partially_ready','failed','cancelled')",
      name: "creative_requests_status_is_known"
    add_check_constraint :creative_requests,
      "media_format IN ('image','video')", name: "creative_requests_media_format_is_known"
    # Three images reads as a choice on a phone; one video is the only
    # defensible number at any credible per-second price.
    add_check_constraint :creative_requests,
      "variant_count BETWEEN 1 AND 3", name: "creative_requests_variant_count_in_range"
    add_check_constraint :creative_requests,
      "media_format <> 'video' OR variant_count = 1", name: "creative_requests_video_is_single"

    # One variant. Created before generation starts, so the screen can show
    # "2 of 3 ready" from rows rather than from a timer.
    create_table :creative_outputs do |t|
      t.references :creative_request, null: false, foreign_key: true
      t.references :media_asset, foreign_key: true

      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.string :outcome
      t.string :error_message
      t.jsonb :metadata, null: false, default: {}
      t.datetime :finished_at

      t.timestamps
    end

    add_index :creative_outputs, %i[creative_request_id position], unique: true

    add_check_constraint :creative_outputs,
      "status IN ('pending','generating','ready','failed')", name: "creative_outputs_status_is_known"
    add_check_constraint :creative_outputs,
      "outcome IS NULL OR outcome IN ('generated','refused','provider_error','unavailable')",
      name: "creative_outputs_outcome_is_known"

    # Added after both tables exist. Set only once a variant is chosen, so a
    # request cannot silently end up with two accepted creatives.
    add_reference :creative_requests, :selected_output,
      foreign_key: { to_table: :creative_outputs }, index: true
  end
end
