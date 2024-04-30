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

ActiveRecord::Schema[7.1].define(version: 2024_04_29_135206) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "message_status", ["inbound", "unsent", "submitted", "delivered", "rejected", "undeliverable"]
  create_enum "user_role", ["user", "team_admin", "site_admin", "super_admin"]

  create_table "contacts", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id", null: false
    t.text "notes"
    t.datetime "notes_updated_at"
    t.bigint "notes_last_editor_id"
    t.bigint "created_by_id"
    t.index ["created_by_id"], name: "index_contacts_on_created_by_id"
    t.index ["notes_last_editor_id"], name: "index_contacts_on_notes_last_editor_id"
    t.index ["phone"], name: "index_contacts_on_phone"
    t.index ["team_id", "phone"], name: "index_contacts_on_team_id_and_phone", unique: true
    t.index ["team_id"], name: "index_contacts_on_team_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "read", default: true
    t.bigint "last_message_id"
    t.index ["contact_id"], name: "index_conversations_on_contact_id"
    t.index ["last_message_id"], name: "index_conversations_on_last_message_id"
  end

  create_table "conversations_users", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "conversation_id", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversations_users_on_conversation_id_and_user_id", unique: true
    t.index ["user_id", "conversation_id"], name: "index_conversations_users_on_user_id_and_conversation_id", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "content"
    t.jsonb "provider_info"
    t.bigint "conversation_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "status", default: "unsent", null: false, enum_type: "message_status"
    t.uuid "outbound_uuid"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["outbound_uuid"], name: "index_messages_on_outbound_uuid"
    t.index ["sender_type", "sender_id"], name: "index_messages_on_sender"
  end

  create_table "teams", force: :cascade do |t|
    t.text "name", null: false
    t.text "slug", null: false
    t.text "address"
    t.text "desc"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

  create_table "templates", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.enum "role", default: "user", null: false, enum_type: "user_role"
    t.string "phone"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "contacts", "teams"
  add_foreign_key "contacts", "users", column: "created_by_id"
  add_foreign_key "contacts", "users", column: "notes_last_editor_id"
  add_foreign_key "conversations", "contacts"
  add_foreign_key "conversations", "messages", column: "last_message_id"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "templates", "users"
end
