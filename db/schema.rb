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

ActiveRecord::Schema[8.1].define(version: 2026_11_09_170005) do
  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "checks", force: :cascade do |t|
    t.integer "uptime_monitor_id", null: false
    t.boolean "up", null: false
    t.integer "http_status"
    t.integer "response_time_ms"
    t.string "error"
    t.datetime "checked_at", null: false
    t.index ["checked_at"], name: "index_checks_on_checked_at"
    t.index ["uptime_monitor_id", "checked_at"], name: "index_checks_on_uptime_monitor_id_and_checked_at"
  end

  create_table "daily_uptimes", force: :cascade do |t|
    t.integer "uptime_monitor_id", null: false
    t.date "date", null: false
    t.integer "checks_count", default: 0, null: false
    t.integer "up_count", default: 0, null: false
    t.index ["date"], name: "index_daily_uptimes_on_date"
    t.index ["uptime_monitor_id", "date"], name: "index_daily_uptimes_on_uptime_monitor_id_and_date", unique: true
  end

  create_table "incident_updates", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_incident_updates_on_incident_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.string "title", null: false
    t.string "status", default: "investigating", null: false
    t.string "impact", default: "minor", null: false
    t.integer "uptime_monitor_id"
    t.boolean "automatic", default: false, null: false
    t.datetime "started_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resolved_at"], name: "index_incidents_on_resolved_at"
    t.index ["status"], name: "index_incidents_on_status"
    t.index ["uptime_monitor_id"], name: "index_incidents_on_uptime_monitor_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscribers", force: :cascade do |t|
    t.string "email_address", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_at"], name: "index_subscribers_on_confirmed_at"
    t.index ["email_address"], name: "index_subscribers_on_email_address", unique: true
  end

  create_table "uptime_monitors", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.integer "interval_seconds", default: 60, null: false
    t.integer "timeout_seconds", default: 10, null: false
    t.integer "expected_status_min", default: 200, null: false
    t.integer "expected_status_max", default: 399, null: false
    t.string "keyword"
    t.integer "failure_threshold", default: 2, null: false
    t.boolean "active", default: true, null: false
    t.string "status", default: "pending", null: false
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "last_checked_at"
    t.datetime "next_check_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "next_check_at"], name: "index_uptime_monitors_on_active_and_next_check_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "checks", "uptime_monitors", on_delete: :cascade
  add_foreign_key "daily_uptimes", "uptime_monitors", on_delete: :cascade
  add_foreign_key "incident_updates", "incidents", on_delete: :cascade
  add_foreign_key "incidents", "uptime_monitors", on_delete: :nullify
  add_foreign_key "sessions", "users"
end
