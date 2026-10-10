class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :department

      t.timestamps
    end
  end
end
