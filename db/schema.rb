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

ActiveRecord::Schema[8.1].define(version: 2026_11_20_000000) do
  create_table "reservations", force: :cascade do |t|
    t.string "contact", null: false
    t.datetime "created_at", null: false
    t.string "customer_name", null: false
    t.text "note"
    t.integer "party_size", null: false
    t.date "reserved_on", null: false
    t.string "time_slot", null: false
    t.datetime "updated_at", null: false
    t.index ["reserved_on", "time_slot"], name: "index_reservations_on_reserved_on_and_time_slot"
    t.check_constraint "party_size > 0", name: "party_size_positive"
  end
end
