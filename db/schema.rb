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

ActiveRecord::Schema[8.1].define(version: 2026_11_13_082442) do
  create_table "expenses", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "payer_id", null: false
    t.string "description", null: false
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "token", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_groups_on_token", unique: true
  end

  create_table "members", force: :cascade do |t|
    t.integer "group_id", null: false
    t.string "name", null: false, collation: "NOCASE"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["group_id", "name"], name: "index_members_on_group_id_and_name", unique: true
    t.index ["user_id", "group_id"], name: "index_members_on_user_id_and_group_id", unique: true
  end

  create_table "participations", force: :cascade do |t|
    t.integer "expense_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id", "member_id"], name: "index_participations_on_expense_id_and_member_id", unique: true
    t.index ["member_id"], name: "index_participations_on_member_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "expenses", "groups", on_delete: :cascade
  add_foreign_key "expenses", "members", column: "payer_id"
  add_foreign_key "members", "groups", on_delete: :cascade
  add_foreign_key "members", "users", on_delete: :nullify
  add_foreign_key "participations", "expenses", on_delete: :cascade
  add_foreign_key "participations", "members"
  add_foreign_key "sessions", "users"
end
