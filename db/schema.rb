# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_user_id"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "workspace_id"
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_user_id"], name: "index_audit_events_on_actor_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["workspace_id", "created_at"], name: "index_audit_events_on_workspace_id_and_created_at", order: { created_at: :desc }
    t.index ["workspace_id"], name: "index_audit_events_on_workspace_id"
  end

  create_table "brand_analyses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "requested_by_id"
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["requested_by_id"], name: "index_brand_analyses_on_requested_by_id"
    t.index ["workspace_id", "created_at"], name: "index_brand_analyses_on_workspace_id_and_created_at", order: { created_at: :desc }
    t.index ["workspace_id"], name: "index_brand_analyses_on_workspace_id"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'analyzing'::character varying, 'partially_complete'::character varying, 'complete'::character varying, 'failed'::character varying]::text[])", name: "brand_analyses_status_is_known"
  end

  create_table "brand_analysis_tasks", force: :cascade do |t|
    t.bigint "brand_analysis_id", null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.datetime "finished_at"
    t.string "outcome"
    t.jsonb "result", default: {}, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.string "task_key", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_analysis_id", "task_key"], name: "index_brand_analysis_tasks_on_brand_analysis_id_and_task_key", unique: true
    t.index ["brand_analysis_id"], name: "index_brand_analysis_tasks_on_brand_analysis_id"
    t.check_constraint "outcome IS NULL OR (outcome::text = ANY (ARRAY['analysed'::character varying, 'insufficient_data'::character varying, 'not_supported'::character varying, 'error'::character varying]::text[]))", name: "brand_analysis_tasks_outcome_is_known"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'analyzing'::character varying, 'complete'::character varying, 'failed'::character varying]::text[])", name: "brand_analysis_tasks_status_is_known"
  end

  create_table "brand_goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "goal", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "goal"], name: "index_brand_goals_on_workspace_id_and_goal", unique: true
    t.index ["workspace_id"], name: "index_brand_goals_on_workspace_id"
    t.check_constraint "goal::text = ANY (ARRAY['increase_sales'::character varying, 'generate_leads'::character varying, 'grow_followers'::character varying, 'boost_engagement'::character varying, 'brand_awareness'::character varying, 'website_visits'::character varying]::text[])", name: "brand_goals_goal_is_known"
  end

  create_table "brand_profiles", force: :cascade do |t|
    t.text "about"
    t.string "business_type"
    t.string "category"
    t.string "city"
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_brand_profiles_on_workspace_id", unique: true
    t.check_constraint "about IS NULL OR char_length(about) <= 500", name: "brand_profiles_about_within_limit"
    t.check_constraint "business_type IS NULL OR (business_type::text = ANY (ARRAY['sole_proprietor'::character varying, 'small_business'::character varying, 'partnership'::character varying, 'private_limited'::character varying, 'llp'::character varying, 'other'::character varying]::text[]))", name: "brand_profiles_business_type_is_known"
  end

  create_table "brand_tones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "tone", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "tone"], name: "index_brand_tones_on_workspace_id_and_tone", unique: true
    t.index ["workspace_id"], name: "index_brand_tones_on_workspace_id"
    t.check_constraint "tone::text = ANY (ARRAY['friendly'::character varying, 'elegant'::character varying, 'playful'::character varying, 'professional'::character varying, 'premium'::character varying, 'educational'::character varying, 'bold'::character varying, 'minimal'::character varying]::text[])", name: "brand_tones_tone_is_known"
  end

  create_table "plan_entitlements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_label", null: false
    t.string "key", null: false
    t.integer "limit_value"
    t.bigint "plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_id", "key"], name: "index_plan_entitlements_on_plan_id_and_key", unique: true
    t.index ["plan_id"], name: "index_plan_entitlements_on_plan_id"
  end

  create_table "plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.string "interval", default: "month", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "price_minor", null: false
    t.boolean "recommended", default: false, null: false
    t.string "tagline"
    t.integer "trial_days", default: 14, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_plans_on_active_and_position"
    t.index ["code", "interval"], name: "index_plans_on_code_and_interval", unique: true
    t.check_constraint "\"interval\"::text = ANY (ARRAY['month'::character varying, 'year'::character varying]::text[])", name: "plans_interval_is_known"
    t.check_constraint "char_length(currency::text) = 3", name: "plans_currency_is_iso4217"
    t.check_constraint "price_minor >= 0", name: "plans_price_not_negative"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "availability_status", default: "available", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.text "description"
    t.boolean "featured", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "price_is_starting_from", default: false, null: false
    t.bigint "price_minor"
    t.string "stock_status", default: "in_stock", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "featured"], name: "index_products_on_workspace_id_and_featured"
    t.index ["workspace_id", "position"], name: "index_products_on_workspace_id_and_position"
    t.index ["workspace_id"], name: "index_products_on_workspace_id"
    t.check_constraint "availability_status::text = ANY (ARRAY['available'::character varying, 'unavailable'::character varying, 'coming_soon'::character varying]::text[])", name: "products_availability_is_known"
    t.check_constraint "char_length(currency::text) = 3", name: "products_currency_is_iso4217"
    t.check_constraint "description IS NULL OR char_length(description) <= 200", name: "products_description_within_limit"
    t.check_constraint "price_minor IS NULL OR price_minor >= 0", name: "products_price_not_negative"
    t.check_constraint "stock_status::text = ANY (ARRAY['in_stock'::character varying, 'low_stock'::character varying, 'out_of_stock'::character varying]::text[])", name: "products_stock_status_is_known"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "availability_status", default: "available", null: false
    t.string "booking_url"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.text "description"
    t.integer "duration_max_days"
    t.integer "duration_min_days"
    t.boolean "featured", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "starting_price_minor"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "featured"], name: "index_services_on_workspace_id_and_featured"
    t.index ["workspace_id", "position"], name: "index_services_on_workspace_id_and_position"
    t.index ["workspace_id"], name: "index_services_on_workspace_id"
    t.check_constraint "availability_status::text = ANY (ARRAY['available'::character varying, 'unavailable'::character varying, 'coming_soon'::character varying]::text[])", name: "services_availability_is_known"
    t.check_constraint "char_length(currency::text) = 3", name: "services_currency_is_iso4217"
    t.check_constraint "description IS NULL OR char_length(description) <= 200", name: "services_description_within_limit"
    t.check_constraint "duration_max_days IS NULL OR duration_min_days IS NULL OR duration_max_days >= duration_min_days", name: "services_duration_range_is_ordered"
    t.check_constraint "duration_min_days IS NULL OR duration_min_days > 0", name: "services_duration_min_positive"
    t.check_constraint "starting_price_minor IS NULL OR starting_price_minor >= 0", name: "services_price_not_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_sessions_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "social_accounts", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "connected_at"
    t.bigint "connected_by_id"
    t.string "connection_status", default: "connected", null: false
    t.datetime "created_at", null: false
    t.datetime "disconnected_at"
    t.string "display_name"
    t.string "external_account_id", null: false
    t.string "granted_scopes", default: [], null: false, array: true
    t.datetime "last_synced_at"
    t.string "missing_scopes", default: [], null: false, array: true
    t.string "permission_status", default: "granted", null: false
    t.string "provider", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.string "username"
    t.bigint "workspace_id", null: false
    t.index ["connected_by_id"], name: "index_social_accounts_on_connected_by_id"
    t.index ["workspace_id", "connection_status"], name: "index_social_accounts_on_workspace_id_and_connection_status"
    t.index ["workspace_id", "provider", "external_account_id"], name: "index_social_accounts_on_workspace_provider_account", unique: true
    t.index ["workspace_id"], name: "index_social_accounts_on_workspace_id"
    t.check_constraint "connection_status::text = ANY (ARRAY['connected'::character varying, 'disconnected'::character varying, 'expired'::character varying, 'revoked'::character varying, 'error'::character varying]::text[])", name: "social_accounts_connection_status_is_known"
    t.check_constraint "permission_status::text = ANY (ARRAY['granted'::character varying, 'partial'::character varying, 'denied'::character varying]::text[])", name: "social_accounts_permission_status_is_known"
    t.check_constraint "provider::text = ANY (ARRAY['instagram'::character varying, 'facebook'::character varying, 'linkedin'::character varying, 'youtube'::character varying, 'tiktok'::character varying, 'google_business'::character varying, 'x'::character varying]::text[])", name: "social_accounts_provider_is_known"
  end

  create_table "social_credentials", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "refresh_token"
    t.bigint "social_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["social_account_id"], name: "index_social_credentials_on_social_account_id", unique: true
  end

  create_table "social_health_scores", force: :cascade do |t|
    t.jsonb "components", default: [], null: false
    t.datetime "computed_at", null: false
    t.integer "coverage_percentage", null: false
    t.datetime "created_at", null: false
    t.string "rating", null: false
    t.integer "score", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "computed_at"], name: "index_social_health_scores_on_workspace_id_and_computed_at", order: { computed_at: :desc }
    t.index ["workspace_id"], name: "index_social_health_scores_on_workspace_id"
    t.check_constraint "coverage_percentage >= 0 AND coverage_percentage <= 100", name: "social_health_coverage_in_range"
    t.check_constraint "rating::text = ANY (ARRAY['needs_work'::character varying, 'fair'::character varying, 'good'::character varying, 'excellent'::character varying]::text[])", name: "social_health_rating_is_known"
    t.check_constraint "score >= 0 AND score <= 100", name: "social_health_score_in_range"
  end

  create_table "staff_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "staff_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_staff_audit_events_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_staff_audit_events_on_created_at", order: :desc
    t.index ["staff_user_id"], name: "index_staff_audit_events_on_staff_user_id"
  end

  create_table "staff_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "revoked_at"
    t.bigint "staff_user_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["staff_user_id", "revoked_at"], name: "index_staff_sessions_on_staff_user_id_and_revoked_at"
    t.index ["staff_user_id"], name: "index_staff_sessions_on_staff_user_id"
    t.index ["token_digest"], name: "index_staff_sessions_on_token_digest", unique: true
  end

  create_table "staff_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.citext "email", null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_staff_users_on_email", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.bigint "plan_id", null: false
    t.string "provider"
    t.string "provider_subscription_id"
    t.bigint "selected_by_id"
    t.string "status", default: "trialing", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["selected_by_id"], name: "index_subscriptions_on_selected_by_id"
    t.index ["workspace_id"], name: "index_subscriptions_on_workspace_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['trialing'::character varying, 'active'::character varying, 'past_due'::character varying, 'cancelled'::character varying, 'expired'::character varying]::text[])", name: "subscriptions_status_is_known"
  end

  create_table "template_favourites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "template_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["template_id"], name: "index_template_favourites_on_template_id"
    t.index ["user_id"], name: "index_template_favourites_on_user_id"
    t.index ["workspace_id", "template_id"], name: "index_template_favourites_on_workspace_id_and_template_id", unique: true
    t.index ["workspace_id"], name: "index_template_favourites_on_workspace_id"
  end

  create_table "template_refreshes", force: :cascade do |t|
    t.integer "added_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.datetime "finished_at"
    t.integer "retired_count", default: 0, null: false
    t.string "source", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["source", "started_at"], name: "index_template_refreshes_on_source_and_started_at", order: { started_at: :desc }
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'complete'::character varying, 'failed'::character varying]::text[])", name: "template_refreshes_status_is_known"
  end

  create_table "templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "aspect_ratio", default: "1:1", null: false
    t.string "content_category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "draft", default: false, null: false
    t.integer "duration_seconds"
    t.integer "favourites_count", default: 0, null: false
    t.datetime "first_seen_at", null: false
    t.integer "generations_count", default: 0, null: false
    t.string "industry"
    t.datetime "last_refreshed_at"
    t.string "media_format", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "premium", default: false, null: false
    t.text "prompt_instructions"
    t.integer "prompt_version", default: 1, null: false
    t.datetime "published_at"
    t.bigint "published_by_id"
    t.datetime "retired_at"
    t.string "slug", null: false
    t.string "source", default: "curated", null: false
    t.string "source_external_id"
    t.string "style_tags", default: [], null: false, array: true
    t.string "supported_platforms", default: [], null: false, array: true
    t.integer "trend_score"
    t.datetime "trend_scored_at"
    t.datetime "updated_at", null: false
    t.index ["content_category", "active"], name: "index_templates_on_content_category_and_active"
    t.index ["draft", "active", "retired_at"], name: "index_templates_on_draft_and_active_and_retired_at"
    t.index ["media_format", "active", "retired_at"], name: "index_templates_on_media_format_and_active_and_retired_at"
    t.index ["published_by_id"], name: "index_templates_on_published_by_id"
    t.index ["slug"], name: "index_templates_on_slug", unique: true
    t.index ["source", "source_external_id"], name: "index_templates_on_source_and_external_id", unique: true, where: "(source_external_id IS NOT NULL)"
    t.index ["style_tags"], name: "index_templates_on_style_tags", using: :gin
    t.index ["trend_score"], name: "index_templates_on_trend_score", order: :desc
    t.check_constraint "content_category::text = ANY (ARRAY['festive'::character varying, 'offer'::character varying, 'new_launch'::character varying, 'behind_the_scenes'::character varying, 'product_showcase'::character varying, 'reels_style'::character varying, 'menu'::character varying, 'tips'::character varying, 'educational'::character varying, 'testimonials'::character varying]::text[])", name: "templates_content_category_is_known"
    t.check_constraint "duration_seconds IS NULL OR duration_seconds > 0", name: "templates_duration_positive"
    t.check_constraint "media_format::text <> 'video'::text OR duration_seconds IS NOT NULL", name: "templates_video_has_duration"
    t.check_constraint "media_format::text = ANY (ARRAY['image'::character varying, 'video'::character varying]::text[])", name: "templates_media_format_is_known"
    t.check_constraint "source::text = ANY (ARRAY['curated'::character varying, 'trend_feed'::character varying, 'partner'::character varying]::text[])", name: "templates_source_is_known"
    t.check_constraint "trend_score IS NULL OR trend_score >= 0 AND trend_score <= 100", name: "templates_trend_score_in_range"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.datetime "last_seen_at"
    t.string "locale", default: "en", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "phone"
    t.string "timezone", default: "Asia/Kolkata", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "(phone IS NOT NULL)"
  end

  create_table "workspace_memberships", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "declined_at"
    t.datetime "expires_at"
    t.citext "invitation_email"
    t.string "invitation_status", default: "pending", null: false
    t.string "invitation_token_digest"
    t.datetime "invited_at"
    t.bigint "invited_by_id"
    t.string "membership_status", default: "active", null: false
    t.datetime "removed_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "workspace_id", null: false
    t.index ["invitation_token_digest"], name: "index_workspace_memberships_on_invitation_token_digest", unique: true
    t.index ["invited_by_id"], name: "index_workspace_memberships_on_invited_by_id"
    t.index ["user_id"], name: "index_workspace_memberships_on_user_id"
    t.index ["workspace_id", "invitation_email"], name: "index_memberships_on_workspace_and_pending_email", unique: true, where: "((invitation_status)::text = 'pending'::text)"
    t.index ["workspace_id", "user_id"], name: "index_memberships_on_workspace_and_user", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
    t.check_constraint "invitation_status::text <> 'accepted'::text OR user_id IS NOT NULL", name: "memberships_accepted_requires_user"
    t.check_constraint "invitation_status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'expired'::character varying, 'cancelled'::character varying]::text[])", name: "memberships_invitation_status_is_known"
    t.check_constraint "membership_status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'removed'::character varying]::text[])", name: "memberships_membership_status_is_known"
    t.check_constraint "user_id IS NOT NULL OR invitation_email IS NOT NULL", name: "memberships_identify_a_person"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "country_code", default: "IN", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.string "locale", default: "en-IN", null: false
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.string "onboarding_step", default: "business_setup", null: false
    t.bigint "owner_user_id", null: false
    t.string "slug", null: false
    t.string "timezone", default: "Asia/Kolkata", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_user_id"], name: "index_workspaces_on_owner_user_id"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
    t.check_constraint "char_length(currency::text) = 3", name: "workspaces_currency_is_iso4217"
    t.check_constraint "onboarding_step::text = ANY (ARRAY['business_setup'::character varying, 'catalog'::character varying, 'connections'::character varying, 'analysis'::character varying, 'health'::character varying, 'plan'::character varying, 'completed'::character varying]::text[])", name: "workspaces_onboarding_step_is_known"
    t.check_constraint "slug::text ~ '^[a-z0-9][a-z0-9-]{1,62}$'::text", name: "workspaces_slug_is_url_safe"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workspaces"
  add_foreign_key "brand_analyses", "users", column: "requested_by_id"
  add_foreign_key "brand_analyses", "workspaces"
  add_foreign_key "brand_analysis_tasks", "brand_analyses"
  add_foreign_key "brand_goals", "workspaces"
  add_foreign_key "brand_profiles", "workspaces"
  add_foreign_key "brand_tones", "workspaces"
  add_foreign_key "plan_entitlements", "plans"
  add_foreign_key "products", "workspaces"
  add_foreign_key "services", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "social_accounts", "users", column: "connected_by_id"
  add_foreign_key "social_accounts", "workspaces"
  add_foreign_key "social_credentials", "social_accounts"
  add_foreign_key "social_health_scores", "workspaces"
  add_foreign_key "staff_audit_events", "staff_users"
  add_foreign_key "staff_sessions", "staff_users"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "subscriptions", "users", column: "selected_by_id"
  add_foreign_key "subscriptions", "workspaces"
  add_foreign_key "template_favourites", "templates"
  add_foreign_key "template_favourites", "users"
  add_foreign_key "template_favourites", "workspaces"
  add_foreign_key "templates", "staff_users", column: "published_by_id"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "users", column: "invited_by_id"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspaces", "users", column: "owner_user_id"
end
