# Content of the "Status normalization" release plan page. Everything about the
# mapping comes from Status (the same table the save path and the backfill use);
# only the human wording and the ordered steps live here.
module ReleasePlan
  Step = Struct.new(:title, :detail, :command, :window, keyword_init: true)

  SAMPLES = [ "comp", "done", "n/a", "", "archived", "xyz" ].freeze

  module_function

  # [{ from: ["completed", "complete", "comp", "done"], to: "completed", label:, rule: }, ...]
  def mapping
    rows = Status::CANONICAL.filter_map do |canonical|
      aliases = Status::ALIASES.select { |raw, target| target == canonical && !raw.empty? && !%w[n/a nil null].include?(raw) }.keys
      { from: [ canonical, *aliases ], to: canonical, rule: aliases.any? ? "Known aliases, mapped one-to-one." : "Already valid." }
    end
    blanks = Status::ALIASES.select { |_, target| target == Status::PENDING }.keys
    rows << { from: blanks.map { |raw| raw.empty? ? '""' : raw }, to: Status::PENDING,
              rule: "Blank values: treated as not started. Rows that already hold answers are listed in the audit report for review." }
    rows << { from: [ "anything else" ], to: Status::UNKNOWN_TARGET,
              rule: "Unknown value: flagged for a human. Original kept in status_legacy and reported." }
    rows.map { |row| row.merge(label: Status.label(row[:to])) }
  end

  def steps
    [
      Step.new(
        title: "Capture and verify a backup",
        detail: "Confirm the backup completed, then prove it is restorable in a throwaway database before touching data.",
        command: "heroku pg:backups:capture --app assessments-prod && heroku pg:backups:info", window: false
      ),
      Step.new(
        title: "Deploy the write-path normalizer",
        detail: 'Aliases like "comp" or "done" are mapped on save; unknown values are rejected. Existing rows are untouched. (Already in this release.)',
        command: "Status.normalize(value) → one of 5 values, else validation error", window: false
      ),
      Step.new(
        title: "Add status_legacy column",
        detail: "Nullable, no default: metadata-only change, no table rewrite. Keeps the original value for rollback.",
        command: "ALTER TABLE assessments ADD COLUMN status_legacy text;", window: false
      ),
      Step.new(
        title: "Add CHECK constraint as NOT VALID",
        detail: "Enforces the five values for new and updated rows only; existing rows are not scanned. Needs a very short exclusive lock, so run it in the window.",
        command: "SET lock_timeout='3s'; ALTER TABLE assessments ADD CONSTRAINT status_allowed CHECK (status IS NOT NULL AND status IN (…)) NOT VALID;",
        window: true
      ),
      Step.new(
        title: "Backfill history in batches",
        detail: "5,000 ids per batch, short pause between batches, resumable and idempotent. Copies the old value to status_legacy first. Review the audit report before running.",
        command: "bin/rails status:backfill:report && bin/rails status:backfill:run CONFIRM=yes BACKUP_TAKEN=yes", window: false
      ),
      Step.new(
        title: "Validate the constraint",
        detail: "Scans the table without blocking reads or writes. Fails, and changes nothing, if any row still breaks the rule.",
        command: "ALTER TABLE assessments VALIDATE CONSTRAINT status_allowed;", window: false
      ),
      Step.new(
        title: "Add the dashboard indexes",
        detail: "Built without locking writes: one orders the page (newest first, ten at a time), one answers the status counts.",
        command: "CREATE INDEX CONCURRENTLY idx_assessments_company_created ON assessments (company_id, created_at DESC, id DESC); …",
        window: false
      ),
      Step.new(
        title: "Drop status_legacy after 14 stable days",
        detail: "Only once no rollback is needed: this discards the originals.",
        command: "ALTER TABLE assessments DROP COLUMN status_legacy;", window: true
      )
    ]
  end

  def rollback
    [
      { when: "During backfill",
        what: "Stop the task. It is resumable and every committed batch is valid on its own, so nothing breaks. The write-path normalizer can stay on: it only writes valid values." },
      { when: "After backfill",
        what: "Drop the CHECK constraint (it forbids the old values), then restore the originals in batches from status_legacy with status:backfill:rollback. The app stays online throughout." },
      { when: "Last resort",
        what: "Restore the pre-release backup (heroku pg:backups:restore) in a low-traffic window with maintenance mode on. Writes made since the backup are lost, so use it only for data corruption." }
    ]
  end

  # What would happen to +raw+ in the historical backfill and on a new save.
  def normalize(raw)
    value = raw.to_s
    canonical = Status.normalize(value)
    valid = Status::CANONICAL.include?(value)
    blank = value.strip.empty? || %w[n/a nil null].include?(value.strip.downcase)
    backfill_status = canonical || Status::UNKNOWN_TARGET

    {
      backfill: {
        status: backfill_status,
        label: Status.label(backfill_status),
        why: if canonical.nil? then "Unknown value: flagged for a human, original kept in status_legacy."
             elsif valid then "Already valid, no change."
             elsif blank then "Blank or not applicable: treated as not started."
             else "Known alias, mapped one-to-one."
             end
      },
      save: {
        accepted: !canonical.nil?,
        status: canonical,
        label: canonical && Status.label(canonical),
        title: canonical ? "Accepted, stored as #{Status.label(canonical)}" : "Rejected",
        why: if canonical.nil? then "Unknown values fail validation. Only the five standard values can be stored."
             elsif valid then "One of the five standard values."
             else "Known alias, normalized on save so only a standard value is stored."
             end
      }
    }
  end
end
