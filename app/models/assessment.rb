class Assessment < ApplicationRecord
  belongs_to :company
  belongs_to :employee

  # Health data and personal identifiers must never reach logs or `inspect`.
  self.filter_attributes += %i[employee_email responses_json]

  validate :employee_belongs_to_company

  private

  # An assessment may only point at an employee of the same tenant.
  def employee_belongs_to_company
    return if employee.nil? || company_id.nil?

    errors.add(:employee, "must belong to the same company") if employee.company_id != company_id
  end
end
