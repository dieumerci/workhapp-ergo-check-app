# Mirrors the inherited legacy table: `status` is a free-form, nullable string
# (years of inconsistent values live in it) and `responses_json` holds the raw
# answers, including free text. Both are intentionally left permissive here;
# the application layer is what tightens them (see Status and Assessment).
class CreateAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :assessments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :employee_email
      t.string :status
      t.jsonb :responses_json

      t.timestamps
    end
  end
end
