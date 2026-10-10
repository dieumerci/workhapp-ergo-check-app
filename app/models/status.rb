# The single definition of what an assessment status can be.
#
# Production standardises on five values going forward. Years of legacy data
# still hold spellings such as "comp", "done", "n/a", nil and "". This module
# is the one place that knows how those map, so the save path, the dashboard
# filters, the CSV export, the backfill and the release-plan tester all agree.
module Status
  PENDING = "pending".freeze
  IN_PROGRESS = "in_progress".freeze
  COMPLETED = "completed".freeze
  NEEDS_FOLLOW_UP = "needs_follow_up".freeze
  ARCHIVED = "archived".freeze

  CANONICAL = [ PENDING, IN_PROGRESS, COMPLETED, NEEDS_FOLLOW_UP, ARCHIVED ].freeze

  LABELS = {
    PENDING => "Pending",
    IN_PROGRESS => "In progress",
    COMPLETED => "Completed",
    NEEDS_FOLLOW_UP => "Needs follow-up",
    ARCHIVED => "Archived"
  }.freeze

  # Legacy spellings that unambiguously mean one of the five values.
  # Matching is case-insensitive and ignores surrounding whitespace.
  ALIASES = {
    "complete" => COMPLETED,
    "comp" => COMPLETED,
    "done" => COMPLETED,
    "n/a" => PENDING,
    "nil" => PENDING,
    "null" => PENDING,
    "" => PENDING
  }.freeze

  # Where a value that matches nothing lands during backfill and in read-only
  # views. Never guessed as "completed": a human reviews these rows.
  UNKNOWN_TARGET = NEEDS_FOLLOW_UP

  # Statuses for which an ergonomic score is meaningful. Pending and
  # in-progress assessments are still being filled in.
  SCORED = [ COMPLETED, NEEDS_FOLLOW_UP, ARCHIVED ].freeze

  module_function

  # The canonical value for +raw+, or nil when the value is unknown.
  # This is what the save path uses: nil means "reject".
  def normalize(raw)
    key = raw.to_s.strip.downcase
    return key if CANONICAL.include?(key)

    ALIASES[key]
  end

  # Like #normalize but never nil: unknown values map to UNKNOWN_TARGET.
  # Used wherever existing rows are displayed, counted or backfilled.
  def classify(raw)
    normalize(raw) || UNKNOWN_TARGET
  end

  # The raw stored values, out of +raw_values+, that classify as +canonical+.
  # Lets a status filter match every legacy spelling of a status (including
  # nil and "") with a plain IN list, so the index can still be used.
  def matching(raw_values, canonical)
    raw_values.select { |raw| classify(raw) == canonical }
  end

  def known?(raw)
    !normalize(raw).nil?
  end

  def label(value)
    LABELS.fetch(value)
  end

  def scored?(value)
    SCORED.include?(value)
  end
end
