# Release runbook: status normalization (plan only)

The operational companion to `SOLUTION.md` §6. **Nothing here has been run against real data.** Replace `assessments-prod` with the real app name.
Assumes PostgreSQL ≥ 12 on a Heroku-like platform. Each step names its script in `db/release_plan/`.

## Roles and rules

- **Driver** runs the steps; **Observer** watches the dashboards and has the authority to say stop.
- One step at a time. Do not start a step until the previous one's *Check* passes and is written down.
- **Stop criteria, any one of them:** p95 response time doubles; database CPU above 80% for 2 minutes; replication lag above 30 s; error rate above baseline; any `lock timeout` repeated 3 times; anything unexpected in the audit report.
- The release is **reversible until step 8**. Do not run step 8 early.

## Before the day

1. Read the audit on a follower if one exists (it scans the table):
   `DATABASE_URL=$(heroku config:get FOLLOWER_URL -a assessments-prod) bin/rails status:backfill:report | tee before.txt`
2. A human reviews the **unknown values** and the **blank-with-answers** count in `before.txt` and decides whether any should map somewhere other than `needs_follow_up`/`pending`. If so, change `Status::ALIASES`, redeploy, and re-run the report.
3. Check free disk and `pg_stat_user_tables` for `assessments` (dead tuples, last autovacuum): the backfill creates dead tuples proportional to the rows it changes.
4. Enable preboot (`heroku features:enable preboot`) so deploys do not drop requests.
5. Pick a low-traffic window for steps 4 and 8, and tell support.

## The steps

### 1. Backup (live)
```bash
heroku pg:backups:capture -a assessments-prod
heroku pg:backups:info <b-id> -a assessments-prod        # Check: status Completed, size plausible
```
Prove it restores, on a scratch app, never on production:
`heroku pg:backups:restore <b-id> DATABASE_URL -a assessments-scratch --confirm assessments-scratch`, then compare `SELECT count(*) FROM assessments` and the status distribution with production. Record the backup id.

### 2. Deploy the write-path normalizer (live)
`git push heroku main` (release phase runs `db:migrate`). **Check:** the app is healthy; saving a record with status `comp` stores `completed`; saving `xyz` is rejected.
The same release carries the idempotent index migration. On a very large table, build the indexes first (step 7's script) so the release phase stays short.

### 3. Add `status_legacy` (live)
`heroku pg:psql -a assessments-prod < db/release_plan/01_add_status_legacy.sql`
**Check:** `\d assessments` shows `status_legacy text`. If `lock timeout` fires, nothing changed: wait and rerun.

### 4. CHECK constraint `NOT VALID` (low-traffic window)
`heroku pg:psql -a assessments-prod < db/release_plan/02_add_status_check_not_valid.sql`
**Check:** `SELECT conname, convalidated FROM pg_constraint WHERE conname = 'status_allowed';` returns `convalidated = f`. Retry on timeout.

### 5. Backfill (live)
```bash
heroku run -a assessments-prod bin/rails status:backfill:report                 # read-only; compare with before.txt
heroku run -a assessments-prod bin/rails status:backfill:run CONFIRM=yes BACKUP_TAKEN=yes BATCH_SIZE=5000 PAUSE=0.2
```
Watch the stop criteria. To pause, `heroku ps:stop run.<n>`; to continue, rerun (it only touches rows that still need it) or pass `FROM_ID`. To go gentler, raise `PAUSE` or lower `BATCH_SIZE` on the next run.
**Check:** the report afterwards shows no aliased, blank or unknown rows left, and the row counts per status match `before.txt` after mapping.

### 6. Validate (live)
`heroku pg:psql -a assessments-prod < db/release_plan/03_validate_status_check.sql`
**Check:** `convalidated = t`. It fails, changing nothing, if a bad row remains: go back to step 5.

### 7. Indexes (live)
`heroku pg:psql -a assessments-prod < db/release_plan/04_dashboard_indexes.sql`
**Check:** no index marked `INVALID` in `\d assessments`. If one is, `DROP INDEX CONCURRENTLY <name>;` and rerun.

### 8. Drop `status_legacy` (low-traffic window, after 14 stable days)
`heroku pg:psql -a assessments-prod < db/release_plan/05_drop_status_legacy.sql`
This discards the originals. Only after two weeks with no rollback needed and no support reports about statuses.

## Rolling back

| Where you are | Do this |
|---|---|
| mid-backfill | stop the run; it is resumable and every committed batch is valid |
| after the backfill, before step 8 | `heroku pg:psql … < db/release_plan/rollback_drop_status_check.sql`, **then** `status:backfill:rollback CONFIRM=yes BACKUP_TAKEN=yes` (online). It restores only rows still holding the backfilled value; any row a person edited since is left alone and counted in the output, with its original in `status_legacy` for you to review |
| code problem | `heroku releases:rollback v<N>` (the additive schema changes are compatible with older code) |
| corruption only | `heroku maintenance:on`; `heroku pg:backups:restore <b-id> DATABASE_URL --confirm assessments-prod`; `heroku maintenance:off`. **Writes since the backup are lost.** |

## Afterwards

Keep `before.txt` and the final report with the release record. Optional, once validated: `ALTER TABLE assessments ALTER COLUMN status SET NOT NULL;` (instant, the validated CHECK proves it) and a default of `pending`.
