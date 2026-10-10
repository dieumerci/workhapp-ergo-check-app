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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_210002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "admins", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_admins_on_company_id"
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "assessment_exports", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "admin_id", null: false
    t.date "from_date"
    t.date "to_date"
    t.string "status_filter", default: "all", null: false
    t.string "state", default: "queued", null: false
    t.integer "progress", default: 0, null: false
    t.integer "row_count"
    t.string "error_code"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_assessment_exports_on_admin_id"
    t.index ["company_id", "created_at"], name: "index_assessment_exports_on_company_id_and_created_at", order: { created_at: :desc }
    t.index ["state", "expires_at"], name: "index_assessment_exports_on_state_and_expires_at"
  end

  create_table "assessments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "employee_id", null: false
    t.string "employee_email"
    t.string "status"
    t.jsonb "responses_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at", "id"], name: "idx_assessments_company_created", order: { created_at: :desc, id: :desc }
    t.index ["company_id", "status", "created_at"], name: "idx_assessments_company_status_created", order: { created_at: :desc }
    t.index ["company_id"], name: "index_assessments_on_company_id"
    t.index ["employee_id"], name: "index_assessments_on_employee_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "department"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_employees_on_company_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admins", "companies"
  add_foreign_key "assessment_exports", "admins"
  add_foreign_key "assessment_exports", "companies"
  add_foreign_key "assessments", "companies"
  add_foreign_key "assessments", "employees"
  add_foreign_key "employees", "companies"
end
