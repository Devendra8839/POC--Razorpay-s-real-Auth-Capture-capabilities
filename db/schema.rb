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

ActiveRecord::Schema[8.0].define(version: 2026_07_02_073541) do
  create_table "payments", force: :cascade do |t|
    t.string "payment_id"
    t.string "order_id"
    t.string "authorization_id"
    t.string "capture_id"
    t.string "refund_id"
    t.string "status"
    t.integer "amount"
    t.string "payment_type"
    t.string "payment_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rental_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "seller_id", null: false
    t.integer "per_day_rent"
    t.integer "security_deposit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["seller_id"], name: "index_products_on_seller_id"
  end

  create_table "rentals", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "renter_id", null: false
    t.integer "days"
    t.integer "rental_amount"
    t.integer "security_amount"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "order_id"
    t.string "security_order_id"
    t.integer "damage_amount"
    t.index ["product_id"], name: "index_rentals_on_product_id"
    t.index ["renter_id"], name: "index_rentals_on_renter_id"
  end

  create_table "sellers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.string "event_type"
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "products", "sellers"
  add_foreign_key "rentals", "products"
  add_foreign_key "rentals", "users", column: "renter_id"
end
