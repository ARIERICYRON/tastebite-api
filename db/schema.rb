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

ActiveRecord::Schema[7.1].define(version: 2026_10_04_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_bookmarks_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_bookmarks_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_likes_on_post_id"
    t.index ["user_id", "post_id"], name: "index_likes_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "meal_plan_entries", force: :cascade do |t|
    t.bigint "meal_plan_id", null: false
    t.bigint "recipe_id", null: false
    t.date "date"
    t.string "meal_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "servings", precision: 10, scale: 2
    t.index ["meal_plan_id"], name: "index_meal_plan_entries_on_meal_plan_id"
    t.index ["recipe_id"], name: "index_meal_plan_entries_on_recipe_id"
  end

  create_table "meal_plans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "week_start_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "weekly_budget", precision: 12, scale: 2
    t.string "location", default: "Toronto", null: false
    t.index ["user_id"], name: "index_meal_plans_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id"
    t.text "caption"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_posts_on_recipe_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "recipe_ingredients", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.string "name"
    t.string "quantity"
    t.string "unit"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_ingredients_on_recipe_id"
  end

  create_table "recipe_reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.integer "rating"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_reviews_on_recipe_id"
    t.index ["user_id"], name: "index_recipe_reviews_on_user_id"
  end

  create_table "recipe_steps", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.text "instruction"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_steps_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.string "difficulty"
    t.integer "time_minutes"
    t.integer "servings"
    t.string "cover_image_url"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "calories"
    t.integer "prep_minutes"
    t.integer "cook_minutes"
    t.integer "protein_g"
    t.integer "carbs_g"
    t.integer "fat_g"
    t.integer "fiber_g"
    t.text "notes"
    t.index ["user_id"], name: "index_recipes_on_user_id"
  end

  create_table "shopping_items", force: :cascade do |t|
    t.bigint "meal_plan_id", null: false
    t.string "ingredient_key", null: false
    t.boolean "checked", default: false, null: false
    t.boolean "pantry", default: false, null: false
    t.decimal "package_price", precision: 12, scale: 2
    t.decimal "package_size", precision: 16, scale: 4
    t.string "package_unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_id", "ingredient_key"], name: "index_shopping_items_on_meal_plan_id_and_ingredient_key", unique: true
    t.index ["meal_plan_id"], name: "index_shopping_items_on_meal_plan_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "handle"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "bio"
    t.string "avatar_url"
    t.string "location"
    t.integer "token_version", default: 0, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["handle"], name: "index_users_on_handle", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookmarks", "recipes"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "likes", "posts"
  add_foreign_key "likes", "users"
  add_foreign_key "meal_plan_entries", "meal_plans"
  add_foreign_key "meal_plan_entries", "recipes"
  add_foreign_key "meal_plans", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "posts", "recipes"
  add_foreign_key "posts", "users"
  add_foreign_key "recipe_ingredients", "recipes"
  add_foreign_key "recipe_reviews", "recipes"
  add_foreign_key "recipe_reviews", "users"
  add_foreign_key "recipe_steps", "recipes"
  add_foreign_key "recipes", "users"
  add_foreign_key "shopping_items", "meal_plans"
end
