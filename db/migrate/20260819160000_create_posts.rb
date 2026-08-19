class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :template, foreign_key: true
      # What the post is about. Polymorphic because a product and a service
      # feed content identically and a shared join would be mostly nulls.
      t.references :subject, polymorphic: true

      t.string :status, null: false, default: "draft"

      t.text :caption
      t.string :hashtags, array: true, null: false, default: []
      t.string :call_to_action
      t.text :first_comment
      t.string :link_url
      t.string :location_name

      # Stored in UTC. The workspace timezone at the moment of scheduling is
      # kept alongside it, so a later timezone change cannot silently move a
      # post that was already scheduled.
      t.datetime :scheduled_at
      t.string :scheduled_timezone
      t.datetime :published_at

      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at

      t.timestamps
    end

    add_index :posts, %i[workspace_id scheduled_at]
    add_index :posts, %i[workspace_id status]

    add_check_constraint :posts,
      "status IN ('draft','awaiting_approval','approved','scheduled','publishing','published','failed','cancelled')",
      name: "posts_status_is_known"
    # A scheduled post with no time is unreachable by the scheduler, and a time
    # with no recorded zone cannot be displayed back correctly.
    add_check_constraint :posts,
      "status <> 'scheduled' OR (scheduled_at IS NOT NULL AND scheduled_timezone IS NOT NULL)",
      name: "posts_scheduled_has_a_time"

    create_table :post_media do |t|
      t.references :post, null: false, foreign_key: true
      t.references :media_asset, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :post_media, %i[post_id position]

    # The table the whole publishing design rests on.
    #
    # A post to three platforms can succeed twice and fail once. One status
    # column on posts could only lie about that, so each platform gets its own
    # row with its own status, its own error and its own idempotency key.
    create_table :post_targets do |t|
      t.references :post, null: false, foreign_key: true
      t.references :social_account, null: false, foreign_key: true
      t.string :provider, null: false

      t.string :status, null: false, default: "pending"
      t.text :caption_override

      t.string :remote_post_id
      t.string :permalink
      t.datetime :published_at

      t.string :error_code
      t.string :error_message
      t.integer :attempt_count, null: false, default: 0
      # Unique so a retry, a double submit, or a Sidekiq redelivery cannot
      # publish the same post twice to the same account.
      t.string :idempotency_key, null: false

      t.timestamps
    end

    add_index :post_targets, %i[post_id social_account_id], unique: true
    add_index :post_targets, :idempotency_key, unique: true
    add_index :post_targets, %i[status published_at]

    add_check_constraint :post_targets,
      "status IN ('pending','validating','publishing','published','failed','skipped')",
      name: "post_targets_status_is_known"
    add_check_constraint :post_targets,
      "provider IN ('instagram','facebook','linkedin','youtube','tiktok','google_business','x')",
      name: "post_targets_provider_is_known"
    # Deliberately no media column here. A per-platform image could only be
    # produced by cropping, which is the media editing this product excludes.
  end
end
