-- Release step 4 - run in a low-traffic window.
-- NOT VALID: the constraint is enforced for rows inserted or updated from now on,
-- but existing rows are NOT scanned, so this is instant. It still needs a brief
-- ACCESS EXCLUSIVE lock to be registered, hence the short lock_timeout and the
-- window; if the timeout fires, nothing was changed, wait a moment and run it again.
-- The application already normalises or rejects statuses on save (step 2), so
-- the app never writes a value this rejects.
SET lock_timeout = '3s';
ALTER TABLE assessments
  ADD CONSTRAINT status_allowed
  CHECK (status IS NOT NULL AND status IN ('pending', 'in_progress', 'completed', 'needs_follow_up', 'archived'))
  NOT VALID;
