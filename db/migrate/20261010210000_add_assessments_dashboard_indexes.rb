# Two indexes for the assessments dashboard. Each answers one query the page
# runs on every view, and each was chosen from EXPLAIN ANALYZE plans rather than
# assumed (numbers in SOLUTION.md, reproducible with `bin/rails perf:report`):
#
#   (company_id, created_at DESC, id DESC)
#     "this company's assessments, newest first, optionally within a date
#     range, ten at a time". Rows come out of the index already sorted, so
#     Postgres reads ten of them and stops instead of reading and sorting every
#     row the company has. ~61 ms -> ~0.2 ms on a 300k-row tenant.
#
#   (company_id, status, created_at DESC)
#     the per-status chip counts. The grouped COUNT is answered from the index
#     alone (an index-only scan) without touching the table. ~38 ms -> ~19 ms
#     on the same tenant.
#
# Both are built CONCURRENTLY so writes to the large assessments table are never
# blocked, which is why this migration opts out of the DDL transaction.
# Explicit up/down, both idempotent (`if_not_exists` / `if_exists`): a retry after
# an interrupted concurrent build, or a rollback of a half-applied release,
# must never fail on an index that is or is not there. If a concurrent build
# is interrupted Postgres leaves an INVALID index behind; drop it
# (`DROP INDEX CONCURRENTLY <name>`) and run the migration again.
class AddAssessmentsDashboardIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = {
    "idx_assessments_company_created" => { columns: %i[company_id created_at id], order: { created_at: :desc, id: :desc } },
    "idx_assessments_company_status_created" => { columns: %i[company_id status created_at], order: { created_at: :desc } }
  }.freeze

  def up
    INDEXES.each do |name, definition|
      add_index :assessments, definition[:columns], order: definition[:order], name: name,
                algorithm: :concurrently, if_not_exists: true
    end
  end

  def down
    INDEXES.each_key do |name|
      remove_index :assessments, name: name, algorithm: :concurrently, if_exists: true
    end
  end
end
