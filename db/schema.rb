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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_130301) do
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
  add_foreign_key "brand_goals", "workspaces"
  add_foreign_key "brand_profiles", "workspaces"
  add_foreign_key "brand_tones", "workspaces"
  add_foreign_key "products", "workspaces"
  add_foreign_key "services", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "users", column: "invited_by_id"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspaces", "users", column: "owner_user_id"
end
