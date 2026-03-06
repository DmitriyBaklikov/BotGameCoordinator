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

ActiveRecord::Schema[7.2].define(version: 2024_01_01_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "game_participants", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.boolean "invited_by_organizer", default: false, null: false
    t.boolean "notified_reserve", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "status"], name: "index_game_participants_on_game_id_and_status"
    t.index ["game_id", "user_id"], name: "index_game_participants_on_game_id_and_user_id", unique: true
    t.index ["game_id"], name: "index_game_participants_on_game_id"
    t.index ["user_id"], name: "index_game_participants_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "organizer_id", null: false
    t.bigint "location_id", null: false
    t.integer "sport_type", null: false
    t.integer "event_type", null: false
    t.string "title", null: false
    t.datetime "scheduled_at", null: false
    t.integer "max_participants", null: false
    t.integer "min_participants", null: false
    t.integer "status", default: 0, null: false
    t.integer "visibility", default: 0, null: false
    t.bigint "chat_id"
    t.bigint "message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_games_on_location_id"
    t.index ["organizer_id", "status"], name: "index_games_on_organizer_id_and_status"
    t.index ["organizer_id"], name: "index_games_on_organizer_id"
    t.index ["status", "scheduled_at"], name: "index_games_on_status_and_scheduled_at"
    t.index ["visibility", "status"], name: "index_games_on_visibility_and_status"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "inviter_id", null: false
    t.bigint "invitee_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "invitee_id"], name: "index_invitations_on_game_id_and_invitee_id", unique: true
    t.index ["game_id"], name: "index_invitations_on_game_id"
    t.index ["invitee_id"], name: "index_invitations_on_invitee_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "organizer_id", null: false
    t.string "name", null: false
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_id", "name"], name: "index_locations_on_organizer_id_and_name"
    t.index ["organizer_id"], name: "index_locations_on_organizer_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "subscriber_id", null: false
    t.bigint "organizer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_id"], name: "index_subscriptions_on_organizer_id"
    t.index ["subscriber_id", "organizer_id"], name: "index_subscriptions_on_subscriber_id_and_organizer_id", unique: true
    t.index ["subscriber_id"], name: "index_subscriptions_on_subscriber_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "state"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0, null: false
    t.string "locale", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  add_foreign_key "game_participants", "games"
  add_foreign_key "game_participants", "users"
  add_foreign_key "games", "locations"
  add_foreign_key "games", "users", column: "organizer_id"
  add_foreign_key "invitations", "games"
  add_foreign_key "invitations", "users", column: "invitee_id"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "locations", "users", column: "organizer_id"
  add_foreign_key "subscriptions", "users", column: "organizer_id"
  add_foreign_key "subscriptions", "users", column: "subscriber_id"
  add_foreign_key "user_sessions", "users"
end
