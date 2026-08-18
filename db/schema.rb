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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_120500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "users", column: "invited_by_id"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspaces", "users", column: "owner_user_id"
end
