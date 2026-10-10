# One CSV export request. Always belongs to the requesting admin's company;
# nothing about the company ever comes from request parameters.
#
#   queued -> processing -> ready (file attached, downloadable for 24 hours)
#                        -> failed (generic error_code, never a raw message)
class AssessmentExport < ApplicationRecord
  STATES = %w[queued processing ready failed].freeze
  STATUS_CHOICES = (Status::CANONICAL + [ "all" ]).freeze
  LINK_LIFETIME = 24.hours
  DOWNLOAD_URL_LIFETIME = 1.minute
  MAX_ACTIVE_PER_COMPANY = 3

  # What a failure means to the user. Raw exception messages can contain SQL
  # and row data, so they are never stored or shown.
  ERROR_MESSAGES = {
    "timeout" => "Timed out while building the file. Try a narrower date range.",
    "error" => "Something went wrong while building the file. Please try again."
  }.freeze

  belongs_to :company
  belongs_to :admin
  has_one_attached :file

  validates :state, inclusion: { in: STATES }
  validates :status_filter, inclusion: { in: STATUS_CHOICES }
  validates :progress, numericality: { in: 0..100 }
  validate :range_is_ordered
  validate :company_has_capacity, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(state: %w[queued processing]) }

  STATES.each do |name|
    define_method(:"#{name}?") { state == name }
  end

  def active?
    queued? || processing?
  end

  def expired?
    ready? && expires_at.present? && expires_at <= Time.current
  end

  def downloadable?
    ready? && !expired? && file.attached?
  end

  # A signed storage link that works for one minute. Callers must have checked
  # authorisation (and #downloadable?) first; the link itself is a bearer token.
  def download_url
    file.url(expires_in: DOWNLOAD_URL_LIFETIME, disposition: "attachment", filename: file.filename)
  end

  # What the page shows; "expired" is derived, not stored.
  def display_state
    expired? ? "expired" : state
  end

  def error_message
    ERROR_MESSAGES[error_code] if failed?
  end

  # Claims the job atomically so it can never run twice.
  def claim!
    claimed = self.class.where(id: id, state: "queued").update_all(state: "processing", started_at: Time.current, updated_at: Time.current)
    reload if claimed == 1
    claimed == 1
  end

  def mark_ready!(row_count:)
    update!(state: "ready", progress: 100, row_count: row_count, finished_at: Time.current, expires_at: LINK_LIFETIME.from_now, error_code: nil)
  end

  def mark_failed!(error_code)
    update!(state: "failed", error_code: error_code, finished_at: Time.current)
  end

  STATE_LABELS = {
    "queued" => "Queued", "processing" => "Building file", "ready" => "Ready", "failed" => "Failed", "expired" => "Expired"
  }.freeze

  # What the page needs; nothing here is personal data.
  def to_view
    {
      id: id,
      state: display_state,
      state_label: STATE_LABELS.fetch(display_state),
      progress: progress,
      row_count: row_count,
      from: from_date&.iso8601.to_s,
      to: to_date&.iso8601.to_s,
      status: status_filter,
      status_label: status_filter == "all" ? "All statuses" : Status.label(status_filter),
      requested_at: created_at.iso8601,
      error: error_message,
      can_retry: failed? || expired?
    }
  end

  # A fresh export with the same two filters (used by "Retry").
  def retry_for(admin)
    company.assessment_exports.new(admin: admin, from_date: from_date, to_date: to_date, status_filter: status_filter)
  end

  private

  def range_is_ordered
    return unless from_date && to_date && from_date > to_date

    errors.add(:base, "Start date is after end date")
  end

  def company_has_capacity
    return if company.nil?
    return if company.assessment_exports.active.count < MAX_ACTIVE_PER_COMPANY

    errors.add(:base, "You already have #{MAX_ACTIVE_PER_COMPANY} exports in progress. Wait for one to finish.")
  end
end
