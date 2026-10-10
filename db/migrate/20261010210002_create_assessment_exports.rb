# A company admin's request for a CSV of their own company's assessments.
# Only the two permitted filters are stored (date range and status); the file
# itself lives in Active Storage and is built by AssessmentExportJob.
class CreateAssessmentExports < ActiveRecord::Migration[8.1]
  def change
    create_table :assessment_exports do |t|
      t.references :company, null: false, foreign_key: true, index: false
      t.references :admin, null: false, foreign_key: true
      t.date :from_date
      t.date :to_date
      t.string :status_filter, null: false, default: "all"
      t.string :state, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.integer :row_count
      t.string :error_code
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :assessment_exports, %i[company_id created_at], order: { created_at: :desc }
    add_index :assessment_exports, %i[state expires_at]
  end
end
