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

ActiveRecord::Schema[8.0].define(version: 2025_08_14_000002) do
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

  create_table "chats", force: :cascade do |t|
    t.text "user_message", null: false
    t.text "ai_response"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "movie_tags", force: :cascade do |t|
    t.integer "movie_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["movie_id", "tag_id"], name: "index_movie_tags_on_movie_id_and_tag_id", unique: true
    t.index ["movie_id"], name: "index_movie_tags_on_movie_id"
    t.index ["tag_id"], name: "index_movie_tags_on_tag_id"
  end

  create_table "movies", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "release_date"
    t.boolean "is_pro"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "series_id", null: false
    t.index ["is_pro", "release_date"], name: "index_movies_on_pro_and_release_date"
    t.index ["release_date"], name: "index_movies_on_release_date"
    t.index ["series_id", "created_at"], name: "index_movies_on_series_and_created_at"
    t.index ["series_id", "release_date"], name: "index_movies_on_series_id_and_release_date"
    t.index ["series_id"], name: "index_movies_on_series_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency", default: "usd", null: false
    t.string "status"
    t.string "stripe_charge_id"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "processed_at"
    t.text "metadata"
    t.index ["status", "created_at"], name: "index_payments_on_status_and_created_at"
    t.index ["stripe_charge_id"], name: "index_payments_on_stripe_charge_id", unique: true
    t.index ["user_id", "created_at"], name: "index_payments_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_payments_on_user_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "series", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["updated_at", "id"], name: "index_series_on_updated_at_and_id"
    t.index ["updated_at"], name: "index_series_on_updated_at"
  end

  create_table "series_tags", id: false, force: :cascade do |t|
    t.integer "series_id", null: false
    t.integer "tag_id", null: false
    t.index ["series_id", "tag_id"], name: "index_series_tags_on_series_id_and_tag_id"
    t.index ["series_id"], name: "index_series_tags_on_series_id"
    t.index ["tag_id", "series_id"], name: "index_series_tags_on_tag_id_and_series_id"
    t.index ["tag_id"], name: "index_series_tags_on_tag_id"
  end

# Could not dump table "sqlite_stat1" because of following StandardError
#   Unknown type '' for column 'tbl'


# Could not dump table "sqlite_stat4" because of following StandardError
#   Unknown type '' for column 'tbl'


  create_table "stripe_events", force: :cascade do |t|
    t.string "event_id", null: false
    t.string "event_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_stripe_events_on_event_id", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description"
    t.index ["created_at"], name: "index_tags_on_created_at"
    t.index ["name", "id"], name: "index_tags_on_name_and_id"
    t.index ["name"], name: "index_tags_on_name"
    t.index ["updated_at", "id"], name: "index_tags_on_updated_at_and_id"
    t.index ["updated_at"], name: "index_tags_on_updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "role"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "last_seen_at"
    t.integer "login_count", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_seen_at"], name: "index_users_on_last_seen_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["updated_at"], name: "index_users_on_updated_at"
  end

  create_table "view_analytics", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "movie_id", null: false
    t.datetime "viewed_at", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.integer "watch_duration"
    t.boolean "completed_viewing", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["movie_id", "viewed_at"], name: "index_view_analytics_on_movie_id_and_viewed_at"
    t.index ["movie_id"], name: "index_view_analytics_on_movie_id"
    t.index ["user_id", "viewed_at"], name: "index_view_analytics_on_user_id_and_viewed_at"
    t.index ["user_id"], name: "index_view_analytics_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "users"
  add_foreign_key "movie_tags", "movies"
  add_foreign_key "movie_tags", "tags"
  add_foreign_key "movies", "series"
  add_foreign_key "payments", "users"
  add_foreign_key "view_analytics", "movies"
  add_foreign_key "view_analytics", "users"
end
