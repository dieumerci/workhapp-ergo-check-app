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
  # The builder touches updated_at after every batch of 1,000 rows (a heartbeat).
  # A "processing" export that has been silent this long lost its worker.
  STALE_AFTER = 10.minutes
  # A "queued" export that nothing picked up in this long lost its job.
  QUEUED_TIMEOUT = 1.hour

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
  # Active AND still alive: what counts towards the per-company cap, so exports
  # whose worker died cannot lock a company out.
  scope :in_flight, -> {
    where(state: "queued", created_at: QUEUED_TIMEOUT.ago..)
      .or(where(state: "processing", updated_at: STALE_AFTER.ago..))
  }
  scope :stalled, -> {
    where(state: "queued", created_at: ...QUEUED_TIMEOUT.ago)
      .or(where(state: "processing", updated_at: ...STALE_AFTER.ago))
  }

  STATES.each do |name|
    define_method(:"#{name}?") { state == name }
  end

  def active?
    (queued? || processing?) && !stalled?
  end

  # Claimed or queued, but nothing has made progress for too long: the worker or
  # the job is gone. Shown as failed (and retryable) at once; ReapStuckExportsJob
  # then records it.
  def stalled?
    (processing? && updated_at < STALE_AFTER.ago) || (queued? && created_at < QUEUED_TIMEOUT.ago)
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

  # Counts one use of the download link. A single atomic UPDATE (no read, no
  # lost update when two admins click at once) that leaves updated_at alone:
  # that column is the build heartbeat, not a "last touched" marker.
  def record_download!
    self.class.where(id: id).update_all([ "download_count = download_count + 1, last_downloaded_at = ?", Time.current ])
  end

  # What the page shows; "expired" and "stalled" are derived, not stored.
  def display_state
    return "failed" if stalled?

    expired? ? "expired" : state
  end

  def error_message
    ERROR_MESSAGES[error_code || "error"] if failed? || stalled?
  end

  # Claims the job atomically so it can never run twice at once. A "processing"
  # export whose heartbeat went silent (its worker died) can be taken over, which
  # is what lets a re-run after a crash or a graceful shutdown finish the work.
  def claim!
    now = Time.current
    claimed = self.class
      .where(id: id)
      .where("state = 'queued' OR (state = 'processing' AND updated_at < ?)", STALE_AFTER.ago)
      .update_all(state: "processing", progress: 0, started_at: now, updated_at: now)
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

  # What the page needs. Nothing about an employee is in here; the requesting
  # admin's name is, because an audit trail that cannot say who exported the
  # data is not one. It is only ever shown to admins of the same company.
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
      requested_by: admin.name,
      download_count: download_count,
      last_downloaded_at: last_downloaded_at&.iso8601,
      expires_at: expires_at&.iso8601,
      expires_in: seconds_until_expiry,
      error: error_message,
      can_retry: failed? || expired? || stalled?
    }
  end

  # How long the download link still works, in seconds, for the countdown on the Exports page. The 24 hours
  # start when the file is ready, so this is nil before then (and for a failed export, which has no file).
  # It is a duration rather than a date so the page counts down from the server's clock, not the browser's.
  def seconds_until_expiry
    return unless ready? && expires_at

    [ (expires_at - Time.current).ceil, 0 ].max
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
    return if company.assessment_exports.in_flight.count < MAX_ACTIVE_PER_COMPANY

    errors.add(:base, "You already have #{MAX_ACTIVE_PER_COMPANY} exports in progress. Wait for one to finish.")
  end
end
