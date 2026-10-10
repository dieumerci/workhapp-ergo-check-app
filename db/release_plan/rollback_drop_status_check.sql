-- Rollback ladder, rung 2: BEFORE restoring original values, drop the constraint
-- (it forbids the legacy values), then run `bin/rails status:backfill:rollback CONFIRM=yes`.
-- Dropping a constraint is instant and safe while the app is live.
SET lock_timeout = '3s';
ALTER TABLE assessments DROP CONSTRAINT IF EXISTS status_allowed;
