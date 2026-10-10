class Assessment < ApplicationRecord
  belongs_to :company
  belongs_to :employee

  # Health data and personal identifiers must never reach logs or `inspect`.
  self.filter_attributes += %i[employee_email responses_json]

  # New and updated records only ever carry one of the five standard statuses.
  # Known legacy aliases ("comp", "done", ...) are normalised; anything else is
  # rejected instead of being stored. Historical rows are handled by the
  # (plan-only) backfill, not here.
  before_validation :normalize_status
  validates :status, inclusion: {
    in: Status::CANONICAL,
    message: "must be one of: #{Status::CANONICAL.join(', ')}"
  }
  validate :employee_belongs_to_company

  private

  def normalize_status
    self.status = Status.normalize(status) || status
  end

  # An assessment may only point at an employee of the same tenant.
  def employee_belongs_to_company
    return if employee.nil? || company_id.nil?

    errors.add(:employee, "must belong to the same company") if employee.company_id != company_id
  end
end
