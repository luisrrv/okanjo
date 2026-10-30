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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_073116) do
  create_table "expenses", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "group_id", null: false
    t.integer "payer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_groups_on_token", unique: true
  end

  create_table "members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id", null: false
    t.string "name", null: false, collation: "NOCASE"
    t.datetime "updated_at", null: false
    t.index ["group_id", "name"], name: "index_members_on_group_id_and_name", unique: true
  end

  create_table "participations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expense_id", null: false
    t.integer "member_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id", "member_id"], name: "index_participations_on_expense_id_and_member_id", unique: true
    t.index ["member_id"], name: "index_participations_on_member_id"
  end

  add_foreign_key "expenses", "groups", on_delete: :cascade
  add_foreign_key "expenses", "members", column: "payer_id"
  add_foreign_key "members", "groups", on_delete: :cascade
  add_foreign_key "participations", "expenses", on_delete: :cascade
  add_foreign_key "participations", "members"
end
