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

ActiveRecord::Schema[7.0].define(version: 2022_12_22_164543) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "message_status", ["inbound", "unsent", "submitted", "delivered", "rejected", "undeliverable"]

  create_table "contacts", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_conversations_on_contact_id"
  end

  create_table "conversations_users", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "conversation_id", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversations_users_on_conversation_id_and_user_id", unique: true
    t.index ["user_id", "conversation_id"], name: "index_conversations_users_on_user_id_and_conversation_id", unique: true
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

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "conversations", "contacts"
  add_foreign_key "messages", "conversations"
end
