class CreateWorkspacePreferences < ActiveRecord::Migration[8.1]
  def change
    # How this workspace's content should sound and how often it should go out.
    # Feeds the generator and pre-fills the post form, which is why it lives in
    # its own table rather than as loose columns on the workspace.
    create_table :posting_preferences do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }

      t.string :brand_voice
      t.string :caption_style, null: false, default: "balanced"
      t.string :hashtag_style, null: false, default: "balanced"
      t.string :emoji_level, null: false, default: "minimal"
      t.string :default_call_to_action

      t.string :brand_keywords, array: true, null: false, default: []
      t.string :avoid_terms, array: true, null: false, default: []

      t.integer :posts_per_week, null: false, default: 3
      # 0 = Sunday, matching Date#wday, so nothing has to translate.
      t.integer :preferred_days, array: true, null: false, default: []
      t.string :preferred_time, null: false, default: "10:00"

      # Publishing defaults. Applied when a post is created, never retrospectively.
      t.boolean :append_hashtags_as_first_comment, null: false, default: false
      t.text :default_first_comment
      t.string :default_link_url

      t.timestamps
    end

    add_check_constraint :posting_preferences,
      "caption_style IN ('short','balanced','storytelling')", name: "posting_caption_style_is_known"
    add_check_constraint :posting_preferences,
      "hashtag_style IN ('none','minimal','balanced','trending')", name: "posting_hashtag_style_is_known"
    add_check_constraint :posting_preferences,
      "emoji_level IN ('none','minimal','moderate','expressive')", name: "posting_emoji_level_is_known"
    add_check_constraint :posting_preferences,
      "posts_per_week BETWEEN 1 AND 21", name: "posting_posts_per_week_in_range"
    add_check_constraint :posting_preferences,
      "preferred_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'", name: "posting_preferred_time_is_a_time"

    # Logo, colours and type. Separate from brand_profile because a brand kit is
    # design material used when generating creatives, not business details.
    create_table :brand_kits do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }

      t.string :primary_color
      t.string :secondary_color
      t.string :accent_color
      t.string :heading_font
      t.string :body_font
      t.text :usage_notes

      t.timestamps
    end

    add_check_constraint :brand_kits,
      "primary_color IS NULL OR primary_color ~* '^#[0-9a-f]{6}$'", name: "brand_kits_primary_is_hex"
    add_check_constraint :brand_kits,
      "secondary_color IS NULL OR secondary_color ~* '^#[0-9a-f]{6}$'", name: "brand_kits_secondary_is_hex"
    add_check_constraint :brand_kits,
      "accent_color IS NULL OR accent_color ~* '^#[0-9a-f]{6}$'", name: "brand_kits_accent_is_hex"

    # Per-person, not per-workspace: two people in one workspace can reasonably
    # want different things emailed to them.
    create_table :notification_preferences do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.boolean :email_post_published, null: false, default: true
      t.boolean :email_post_failed, null: false, default: true
      t.boolean :email_weekly_summary, null: false, default: true
      t.boolean :email_team_activity, null: false, default: false
      t.boolean :email_product_news, null: false, default: false

      t.timestamps
    end

    add_index :notification_preferences, %i[workspace_id user_id], unique: true
  end
end
