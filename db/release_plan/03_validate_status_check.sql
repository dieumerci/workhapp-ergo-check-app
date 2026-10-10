-- Release step 6 - safe while the app is live.
-- Run only after `bin/rails status:backfill:report` shows no rows left to change.
-- VALIDATE takes a SHARE UPDATE EXCLUSIVE lock: it scans the table but reads and
-- writes carry on. It fails (and changes nothing) if any row still violates the
-- constraint, which is exactly the safety net we want.
SET statement_timeout = 0;
ALTER TABLE assessments VALIDATE CONSTRAINT status_allowed;
