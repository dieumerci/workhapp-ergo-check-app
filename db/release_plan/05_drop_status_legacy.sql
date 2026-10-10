-- Release step 8 - low-traffic window, and ONLY after 14 days with no rollback needed.
-- Dropping the column discards the originals, so this is the point of no return for
-- the backfill. (DROP COLUMN is quick - it only marks the column dead - but it takes
-- a brief ACCESS EXCLUSIVE lock, hence the window.)
SET lock_timeout = '3s';
ALTER TABLE assessments DROP COLUMN IF EXISTS status_legacy;

-- Optional follow-up once the constraint is validated: Postgres can use a validated
-- CHECK to prove there are no NULLs and skip the scan, so this is instant.
--   ALTER TABLE assessments ALTER COLUMN status SET NOT NULL;
--   ALTER TABLE assessments ALTER COLUMN status SET DEFAULT 'pending';
