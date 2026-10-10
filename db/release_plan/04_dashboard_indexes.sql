-- Release step 7 - safe while the app is live. Outside a transaction.
-- CONCURRENTLY never blocks writes; it takes longer and must not run inside BEGIN/COMMIT.
-- The same two indexes ship as the Rails migration AddAssessmentsDashboardIndexes
-- (idempotent), so on a very large table build them with this script ahead of the
-- deploy and the migration then finds them already there.
--   1. the dashboard page: company's rows newest first, ten at a time
--   2. the status chip counts, answered from the index alone
-- If a concurrent build is interrupted it leaves an INVALID index: drop it with
--   DROP INDEX CONCURRENTLY <name>;  and run this again.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assessments_company_created
  ON assessments (company_id, created_at DESC, id DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assessments_company_status_created
  ON assessments (company_id, status, created_at DESC);
