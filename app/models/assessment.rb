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

  # A new record with no status starts as pending, and a legacy row that is left
  # untouched keeps normalising ("" and nil mean "not started"). But explicitly
  # setting an existing assessment's status to blank is a mistake, not a request to
  # reset it, so it is left blank for the validation below to reject. (Otherwise a
  # PATCH that forgot the status param would silently turn an archived assessment
  # into a pending one.)
  def normalize_status
    return if persisted? && status_changed? && status.to_s.strip.empty?

    self.status = Status.normalize(status) || status
  end

  # An assessment may only point at an employee of the same tenant.
  def employee_belongs_to_company
    return if employee.nil? || company_id.nil?

    errors.add(:employee, "must belong to the same company") if employee.company_id != company_id
  end
end
