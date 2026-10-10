-- Release step 3 - safe while the app is live.
-- Nullable column with no default is a metadata-only change in Postgres: no
-- table rewrite, no scan. It holds the ORIGINAL status of every row the
-- backfill changes, which is what makes the backfill reversible.
-- lock_timeout stops this from queueing behind a long transaction and, in doing
-- so, blocking every other query on the table; if it times out, just run it again.
SET lock_timeout = '3s';
ALTER TABLE assessments ADD COLUMN IF NOT EXISTS status_legacy text;
