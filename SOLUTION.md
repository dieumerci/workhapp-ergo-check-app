# SOLUTION

How the three tasks were solved, why each choice was made, what was measured, and what I would not do. The rule
I followed throughout, from the brief: *operate with restraint*. Targeted, safe changes; no rewrites.

**Contents** — [1 Summary](#1-summary) · [2 Requirement traceability](#2-requirement-traceability) ·
[3 The one rule that matters](#3-the-one-rule-that-matters-the-tenant-comes-from-the-session) ·
[4 Task 1: export](#4-task-1--company-scoped-csv-export) · [5 Task 2: dashboard](#5-task-2--dashboard-speed-and-the-score) ·
[6 Task 3: statuses](#6-task-3--normalizing-statuses-with-a-safe-release-plan) · [7 Sign-in, CAPTCHA, cookies](#7-sign-in-captcha-and-cookies) ·
[8 Departures from the design](#8-where-i-departed-from-the-design-and-why) · [9 Trade-offs](#9-trade-offs-and-what-i-would-do-next) ·
[10 Build log](#10-build-log-the-steps-and-why-each-was-done-this-way) · [11 Verification](#11-how-this-was-verified-and-what-was-not)

---

## 1. Summary

| | What changed | The evidence |
|---|---|---|
| **Task 1** | One tenant-scoped export endpoint with two filters, built by a background job, six redacted columns, tenant-checked download that expires in 24 h. | 40+ tests including cross-tenant attempts; mutation checks (removing the tenant scope fails the tests); the real file inspected in a browser. |
| **Task 2** | One grouped `COUNT` plus one page of ten rows replaces "load everything, then one query per row". Two measured indexes. Score is the rounded mean of four sections or an explicit "Not scored yet". | A replay of the inherited behaviour took **94.5 s and 300,001 queries** for a 300k-row company; the new page takes **23 ms and 2 queries**. |
| **Task 3** | `Status` is the single definition; aliases are mapped and unknown values rejected on save. The backfill is guarded, batched, resumable and reversible, and **was not run**. | A test proves the SQL mapping agrees with the Ruby one on awkward input; the plan and rollback are in §6. |

Things I deliberately did **not** do: rewrite the module, add a second UI framework, run the historical backfill,
or push the repository anywhere.

## 2. Requirement traceability

| Brief says | Where | Verified by |
|---|---|---|
| Export only for the admin's own company | `ExportsController` takes the company from `Current.company` for every lookup | `exports_test`: cross-tenant download/retry → 404; `company_id` params ignored; mutation check |
| Do not rely on a client-provided company id | No code reads `params[:company_id]` anywhere | `AssessmentsDashboardTest`, `ExportsTest` send a rival `company_id` and assert nothing changes |
| Filters limited to exactly two | `ExportsController#build_export` reads `from`, `to`, `status` only | `exports_test`: extra params (`department`, `employee_email`, `admin_id`…) are ignored |
| Exclude/redact free text and identifiers | Builder reads six columns via `AssessmentRow`; `employee_ref` is an HMAC | `AssessmentExportsBuilderTest`: no name, e-mail, free text, raw key anywhere in the file |
| Minimal TypeScript UI with feedback | Export dialog (live count, progress, ready, failed) and Exports page | Walked through in the browser; states match the design |
| Streaming *or* async, justified | Async, §4.1 | — |
| No sensitive values in logs | Filter list, filtered attributes, filtered redirects, generic failure codes | `log_hygiene_test` and `exports_test` read the real DEBUG log |
| One measurable dashboard improvement, before/after note | §5.2–5.3, raw output in `benchmarks/` | `bin/rails perf:report` reproduces it |
| Score present and correct | `ScoreCalculator` | `score_calculator_test` (10 tests, 33 assertions) and the dashboard tests |
| Reduce sensitive data in logs here | same as above | same |
| Keep the page working, smallest change | Same page, same data, same URL | Existing behaviour covered by tests |
| New/updated records use only the five statuses | `Status` + `Assessment` validation | `status_test`, `assessment_test` |
| Design (don't fully run) a backfill with mapping and unknown handling | `StatusBackfill`, §6.2–6.3 | `status_backfill_test` (16 tests, run inside a rolled-back transaction) |
| Step-by-step release and rollback, backup, live vs window | §6.4–6.6, `db/release_plan/RUNBOOK.md` | The Release plan page renders the same steps from `ReleasePlan` |
| Keep the app responsive; no table stalls | Batched, short transactions, lock/statement timeouts, `CONCURRENTLY`, `NOT VALID` | `status_backfill_test`; SQL in `db/release_plan/` |
| README with run instructions, SOLUTION.md | These files | — |
| Video demo | **Not recorded** (it needs your voice). `README.md` has a timed script. | — |

## 3. The one rule that matters: the tenant comes from the session

`Current.company` is derived from the signed-in admin. Every controller, job and query reaches data through
`Current.company.<association>`. There is no parameter, header or cookie that names a company, so there is nothing for a
client to forge. That is why the multi-tenant tests are short: they send a rival company id and assert it changes nothing,
and the mutation checks (swap `Current.company.assessment_exports.find` for `AssessmentExport.find`, or build the export
scope from `Assessment.all`) make those tests fail, which is the proof they are not vacuous.

Looking up another company's record is a **404**, not a 403: the response does not confirm the record exists.

## 4. Task 1 — company-scoped CSV export

### 4.1 Async, not streaming — and why

| | Streaming (`send_stream`) | Background job (chosen) |
|---|---|---|
| Ties up a web worker for the whole export | **yes** — a big company holds a Puma thread (and a Heroku router 30 s limit looms) | no |
| Progress, retry, history, "come back later" | no | yes — the design already shows these states |
| Survives a closed tab / dropped connection | no | yes |
| Moving parts | none | job queue + file storage |
| Failure handling | half-written response | a recorded, retryable failure |

The design's "Exports" page, progress bar, "Ready", "Failed" and "Retry" only make sense for the async approach, and the
brief says the largest table stalls easily, so I chose the option that never holds a web thread. The cost is two moving
parts (Solid Queue and Active Storage), both of which Rails 8 ships.

### 4.2 Redaction by construction, not by filtering

The builder never loads a sensitive column. It uses `AssessmentRow.export_relation`, which selects `id`, `employee_id`, `status`, `created_at`, the
employee's department, and **only** `responses_json -> 'section_scores'` (four small numbers). The e-mail column, the employee
name and the free text are never read, so they cannot leak through a bug in a formatter; a test captures the batch SQL and asserts it never mentions them.
(An independent review pointed out that the first version reused the dashboard's select, which includes the name for display. It never reached the file, but "redaction by construction" should be literally true, so the export now has its own select.)

| Column | Source | Notes |
|---|---|---|
| `assessment_id` | `A-<id>` | |
| `employee_ref` | `emp_` + 12 hex of HMAC-SHA256(company id, employee id) | one-way, stable, differs per company; lets an admin join rows to people they can already see |
| `department` | employee | guarded against spreadsheet formulas (see below) |
| `status` | the five standard values | legacy spellings are folded in, never exported raw |
| `score` | rounded mean of four sections | blank when not scored |
| `created_at` | date, `YYYY-MM-DD` | |

**CSV injection.** A department that starts with `=`, `+`, `-`, `@`, tab or CR would be executed as a formula by Excel. Such cells
are prefixed with `'` (tested, including embedded commas, quotes and newlines).

**Employee reference length.** The design shows 4 hex characters (`emp_a41f`); that is only 65,536 values, so two employees of a
large company would collide. I used 12 (48 bits, negligible collisions even at 100,000 employees).

### 4.3 The job

- **Atomic claim** (`UPDATE … WHERE state='queued'`) so a duplicated job can never build twice.
- **Batches of 1,000** by primary key, written to a temp file: memory stays flat whatever the company size.
- **Real progress** saved after each batch, capped at 99 until the file is attached.
- **Time budget** (`EXPORT_MAX_SECONDS`, default 300): a runaway export fails with the design's "try a narrower date range" message instead of holding a worker.
- **Generic failures.** An exception's message can contain SQL and row values, so only its *class name* is logged and the export stores a code (`timeout` or `error`) that maps to fixed wording. The job takes only the export id as an argument, and argument logging is switched off.
- **Capacity.** At most three exports in flight per company; ten requests per hour per client.

### 4.4 Download and retention

Downloading re-checks the tenant, then redirects to a **one-minute signed storage URL**, so the file never streams through
Rails and the link is useless a minute later. Exports are valid for 24 hours; a daily job purges expired files so exported data
does not linger. The Rails log would have written that signed URL in full ("Redirected to …"), which I found by reading the worker
log in production mode; `filter_redirect` now masks it (tested).

### 4.5 Trade-offs

- Exports are ordered by id (creation order), not newest-first: ordering a million rows by date is a sort for no benefit to a file.
- A file larger than memory is fine to *build*, but the disk service's download is whatever the storage service supports (S3 handles it).
- Two services to operate instead of zero; accepted for the reasons in §4.1.

## 5. Task 2 — dashboard speed and the score

### 5.1 What "slow" most plausibly was

I did not have the legacy code, so I worked from the brief's symptoms and rebuilt the behaviour it implies (`Perf.legacy_page` in
`lib/tasks/perf.rake`): load **every** assessment of the company with **every** column (raw answers included), look the employee up
**one row at a time**, score each row in Ruby, count statuses in Ruby, render everything. That is unbounded in rows, in columns and in queries.

### 5.2 The smallest change that fixes it

`AssessmentDashboard` answers a page in **two queries**:

1. one grouped `COUNT` of the company's assessments in the date range, by raw status. Legacy spellings are folded into the five
   statuses in Ruby, so the chips, the status filter and the pagination total always agree, even before the backfill;
2. one page of ten rows with the employee **joined** in, selecting only the columns the page shows.

The page, URL and behaviour are unchanged. Opening the detail drawer is a *partial reload* that does no dashboard work at all (tested: one query).

### 5.3 Measured before and after

Environment: Apple M5 Pro, PostgreSQL 18.6, Ruby 3.3.12, development mode. One large tenant of N assessments inside a table that also holds
3×N rows for 20 other tenants (so the planner has to find the tenant's rows among everyone's). Times are the median of 5 runs for the new page and a
single run for the legacy replay. Raw output: [`benchmarks/dashboard-2026-10-10.txt`](benchmarks/dashboard-2026-10-10.txt); reproduce with `bin/rails perf:report`.

| Tenant rows | **Before** (replay of inherited page) | **After** (shipped) | Queries before → after | Ruby objects before → after |
|---:|---:|---:|---:|---:|
| 5,000 | 1,442 ms | 3 ms | 5,001 → 2 | 2.7 M → 2.4 k |
| 25,000 | 7,153 ms | 4 ms | 25,001 → 2 | 13.7 M → 2.4 k |
| 100,000 | 29,825 ms | 8 ms | 100,001 → 2 | 54.8 M → 2.4 k |
| 300,000 | **94,533 ms** | **23 ms** | **300,001 → 2** | **164 M → 2.4 k** |

The legacy cost grows linearly with the data; the new cost is nearly flat. For the status-filtered view at 300k rows: 11,499 ms / 39,882 queries before, 23 ms / 2 queries after.

**Why those two indexes, and not the one in the design.** I looked at `EXPLAIN ANALYZE` rather than assume. For the 300k-row tenant (warm cache, best of 5):

| Index set | Chip counts query | Page query |
|---|---:|---:|
| none (code change only) | 40 ms | 61 ms |
| `(company_id, created_at DESC, id DESC)` | 38 ms | **0.19 ms** |
| that plus `(company_id, status, created_at DESC)` | **19 ms** | 0.22 ms |

The design prototype suggested `(company_id, status, created_at DESC)` alone. That index does **not** help the page query: Postgres ignores it and sorts, still 50–88 ms.
What helps is an index whose order *is* the sort order: rows come out already ordered and the scan stops after ten (≈300×). The status index earns its place on the
counts query, which it answers from the index alone (index-only scan) for a further 2×. Both are built `CONCURRENTLY` (no write blocking) and the migration is idempotent in both directions.

**Why this change.** It removes the unbounded work (the dominant cost), the N+1, and the wide-row loading, using one grouped query and standard Postgres indexes: no caching layer, no denormalized
column, no background precomputation, nothing to invalidate. **Caveats:** local, one machine; the "before" is a faithful replay of the described behaviour, not the lost original; on a busy production
database absolute numbers will differ, but the shape (linear vs flat) will not. I did not add caching of the counts: at 23 ms it is not needed, and a stale chip count is a worse bug than a slow one.

### 5.4 The score

`ScoreCalculator` implements the design's rule exactly: **the rounded average of the four section scores**, shown for completed, needs-follow-up and archived assessments.

| Input | Result | Why |
|---|---|---|
| four numbers 0–100 | rounded mean (`.5` rounds up, like the prototype's `Math.round`) | the rule |
| `"74"`, `" 70 "`, `74.0` | counted | legacy rows stored strings; naive `+` would concatenate them into nonsense ("obviously off") |
| a section missing, `null`, `"n/a"`, `true`, `[]` | **no score** | a partial average is a wrong number |
| `-1`, `101`, `NaN`, `Infinity` | **no score** | out of range |
| status pending / in progress | no score, even if answers exist | still being filled in; shown as "Not scored yet" |
| scored status but unusable data | no score, with its own message in the drawer | honest about *why* |

**Why derive it at read time instead of storing a `score` column.** One source of truth that cannot go stale or be wrong for a row nobody backfilled; no migration, no callback, no
backfill on the big table (which the brief says to avoid). The page reads only the four small numbers it needs, so the cost is negligible. Moving a record to Pending hides the score without destroying the answers; moving it back restores it.

### 5.5 Logging in this area

Request parameters carrying personal data are filtered (`employee_email`, `responses…`, `free_text`, `answers`, the CAPTCHA, passwords), model attributes are filtered from `inspect` and SQL binds, the dashboard never selects
the sensitive columns in the first place, and exception messages never reach the log. The tests do not trust the configuration: they capture the real DEBUG log while requests carrying and returning sensitive data run, and assert
nothing leaks and that harmless fields (`status`, dates) stay visible for debugging. A mutation check confirms they fail when the filters are removed.

## 6. Task 3 — normalizing statuses with a safe release plan

### 6.1 The write path (implemented)

`Status` is the single definition: five canonical values, an alias table, `normalize` (nil = unknown) and `classify` (unknown → `needs_follow_up`, never guessed as completed). `Assessment` normalises known aliases and rejects everything else on **every**
save, so even an unrelated update to a legacy row (`status: "done"`) leaves it as `completed`. A nil status on a new record becomes `pending`.

### 6.2 Mapping and unknowns

| Existing value | Becomes | Rule |
|---|---|---|
| `completed`, `complete`, `comp`, `done` | `completed` | known aliases |
| `pending`, `in_progress`, `needs_follow_up`, `archived` | unchanged | already valid |
| `nil`, `""`, `"n/a"`, `"nil"`, `"null"` | `pending` | blank = not started |
| anything else (`"on hold"`, `"finished"`, …) | `needs_follow_up` | **flagged for a human**; original kept in `status_legacy` and listed by the audit report |

Matching ignores case and surrounding whitespace (`" DONE "` → `completed`). Unknown values are never mapped to `completed`: a person reviews them.
`bin/rails status:backfill:report` also counts blank statuses that **already carry answers**, which a human should look at before the run.

### 6.3 The backfill (designed, tested, not executed)

`StatusBackfill` guarantees:

- **Reversible, without undoing later work.** The original is copied to `status_legacy` first (a sentinel stands in for NULL), and rollback restores it exactly, tested including NULL, `""`, whitespace and unknown values. It restores a row **only if its status is still what the backfill set**: if a person changed it afterwards their edit wins, the row keeps its `status_legacy` for review, and the run reports how many were left (an independent review caught the first version overwriting such edits).
- **Minimal writes.** Only rows that need changing are updated; valid rows are untouched. `updated_at` is left alone (this is not a user change).
- **Idempotent and resumable.** `status_legacy IS NULL` marks "not yet processed"; running twice changes nothing; `FROM_ID` resumes.
- **Does not stall the table.** Batches of 5,000 ids, each its own transaction with `lock_timeout=2s` and `statement_timeout=30s`, retried on lock waits, with a pause between batches.
- **One mapping.** The SQL `CASE` is generated from `Status`, and a test checks it against `Status.classify` on awkward inputs (tabs, newlines, case).
- **Guarded.** Refuses without `CONFIRM=yes`, without the `status_legacy` column, and in production without `BACKUP_TAKEN=yes`; rollback refuses while the CHECK constraint is present (it forbids the old values).

### 6.4 Step-by-step release plan

DDL lives in `db/release_plan/*.sql`, **not** in `db/migrate`, so `db:migrate` can never run part of the plan. Assumes PostgreSQL ≥ 12 and a Heroku-like platform.

| # | Step | Command | When | Why it is safe |
|---|---|---|---|---|
| 1 | **Capture and verify a backup** | `heroku pg:backups:capture` then `pg:backups:info` | live | read-only; see §6.5 |
| 2 | **Deploy the write-path normalizer** (this repo) | `git push heroku main` | live | adds no schema change; new writes are valid from now; existing rows untouched |
| 3 | **Add `status_legacy`** | `01_add_status_legacy.sql` | live | nullable, no default = metadata-only, no rewrite; `lock_timeout` stops it queueing behind a long transaction |
| 4 | **Add the CHECK constraint `NOT VALID`** | `02_add_status_check_not_valid.sql` | **low-traffic window** | enforced for new/updated rows only, no scan; needs a brief exclusive lock, so run it when few transactions are open (retry on timeout, nothing changes) |
| 5 | **Backfill in batches** | `status:backfill:report`, then `run CONFIRM=yes BACKUP_TAKEN=yes` | live | short transactions, throttled, resumable, reversible |
| 6 | **Validate the constraint** | `03_validate_status_check.sql` | live | `SHARE UPDATE EXCLUSIVE`: scans without blocking reads or writes; fails (changes nothing) if any bad row remains |
| 7 | **Add the dashboard indexes** | `04_dashboard_indexes.sql` (or the migration) | live | `CONCURRENTLY`: never blocks writes |
| 8 | **Drop `status_legacy` after 14 stable days** | `05_drop_status_legacy.sql` | **low-traffic window** | point of no return for the originals; brief exclusive lock |

Notes on ordering:
- **Step 7 is independent of the rest.** The repository ships it as an idempotent migration that runs with the first deploy; on a very large table pre-build it with the SQL script off-peak first (Heroku's release phase has a time limit). The extra index maintenance during the backfill is small because only rows with non-standard statuses are written.
- **Step 4 before step 5** means every backfill write is validated by the database too. Step 2 before 4 matters: the app must already normalise, otherwise a stale code path could hit the new constraint.
- Optional once validated: `SET NOT NULL` on `status` (instant, because the validated CHECK proves it) and a default of `pending`.

**Verification after each step:** step 3 `\d assessments`; step 4 `SELECT conname, convalidated FROM pg_constraint WHERE conname='status_allowed'` (expect `f`); after 5, `status:backfill:report` shows nothing left to change and the unknown list has been reviewed; after 6, `convalidated = t`; after 7, `\d assessments` (no `INVALID` indexes); after 8, the column is gone.

### 6.5 Backup and recovery (Heroku-like)

```bash
# before step 3
heroku pg:backups:capture --app assessments-prod
heroku pg:backups:info <b-id> --app assessments-prod          # must say "Completed"
# prove it restores (on a scratch app/database, never on production)
heroku pg:backups:restore <b-id> DATABASE_URL --app assessments-scratch --confirm assessments-scratch
# record the "before" picture so the "after" can be compared
bin/rails status:backfill:report > before.txt                  # run against a follower if one exists
```

**Recovery.** The original statuses live in `status_legacy`, so for a *status* problem the rollback needs no backup and no downtime (§6.6, rung 2). The backup is for
corruption: `heroku maintenance:on`, `heroku pg:backups:restore <b-id> DATABASE_URL --confirm assessments-prod`, `heroku maintenance:off`. **Everything written after the backup is lost**, which is why it is the last rung.
On Heroku Postgres Premium, point-in-time rollback to a new database is an alternative that loses less.

### 6.6 Rollback ladder

| Rung | Situation | Action | Impact |
|---|---|---|---|
| 1 | during the backfill | stop the task (Ctrl-C or `heroku ps:stop`) | none: resumable, every committed batch is valid; the normalizer can stay on |
| 2 | after the backfill | `rollback_drop_status_check.sql` (drop the constraint **first**), then `status:backfill:rollback CONFIRM=yes` | none: online; edits made since the backfill are kept and reported |
| 3 | corruption | restore the pre-release backup in a maintenance window | loses writes since the backup |

Code can be rolled back independently with `heroku releases:rollback`; the database is not rolled back by that, which is fine because the schema changes are additive.

### 6.7 Keeping the app responsive

Throttle (`PAUSE`, `BATCH_SIZE` tunable at run time), run the backfill as a one-off dyno using one connection, watch `pg_stat_activity` and replication lag, and stop at the first sign of trouble. Each batch updates a bounded id range, so a pause between batches lets autovacuum keep up with the dead tuples the updates create.

## 7. Sign-in, CAPTCHA and cookies

**Sign-in.** Encrypted, HttpOnly, SameSite=Lax session cookie (Secure in production), reset on sign-in (no fixation) and sign-out, 8-hour idle expiry, one generic failure message (no account enumeration), rate limiting, `no-store` on every authenticated response.

**CAPTCHA.** Self-hosted: no third party, no keys, works offline. The challenge is a **PNG** rendered server-side (pure Ruby, `chunky_png`) with per-glyph rotation, a sine warp, crossing lines and noise. It is deliberately an image, not text in the page, so the
answer is never in the DOM. Only an HMAC digest and an expiry are stored, in a **server-side `captcha_challenges` row**; the browser's session holds just the row id. Each challenge is single-use because verifying *deletes* the row (the delete is the gate), expires in 5 minutes and is checked *before* the password.
An independent review showed that keeping the digest in the cookie-store session made it replayable (one solved challenge passed 10 of 10 replays of the original cookie); moving it server-side fixed that, and the replay tests would catch a regression.

**Accessible alternative.** An image CAPTCHA locks out blind users (WCAG 1.1.1 and 3.3.8), so the sign-in page offers "Can't see the image? Use a text question instead": a short sum ("What is 36 minus 25?") a screen reader can read aloud, using the same server-side single-use mechanism. It is
easier for a program than the image, so it is limited to 6 requests per hour per address; the real brute-force defences are the per-address (10 per 3 minutes) and per-account (6 per 10 minutes) sign-in limits, which apply either way. **Trade-off:** a determined attacker will pick the text mode, so the CAPTCHA adds
less than it appears to; it is defence in depth, not the lock. If stronger bot resistance is needed, swap in Turnstile or hCaptcha (both have accessible challenges) behind the same `Captcha.verify?` call.

**Sessions.** The cookie holds a random token; a server-side `admin_sessions` row holds its digest. Signing out deletes the row, so a copied cookie stops working (tested), and the server, not a client-held timestamp, enforces the 8-hour idle expiry. The exports poller sends `X-Background-Poll` so a tab left open in the background no longer keeps a session alive indefinitely.

**Cookies.** Strictly-necessary cookies need no consent; the one optional cookie (remembered dashboard filters) is written **only after opt-in**, is signed, validated against a whitelist on read, and deleted on withdrawal. Consent is explicit: only the literal `"true"` grants it (a test caught Rails' loose boolean casting accepting `"yes please"`). The same consent gates `localStorage` for the release-step ticks.

## 8. Where I departed from the design, and why

| Design said | I did | Why |
|---|---|---|
| Index `(company_id, status, created_at DESC)` | Added it **and** `(company_id, created_at DESC, id DESC)` | `EXPLAIN` showed the design's index does not help the page query (§5.3) |
| Restore from `status_legacy`, then drop the CHECK | Drop the CHECK **first** | the constraint forbids the legacy values, so restoring first would be rejected |
| CHECK `status IN (…)` | `status IS NOT NULL AND status IN (…)` | `IN` lets NULL through |
| "Blank-with-responses → needs follow-up" | Blank → `pending`; blanks that carry answers are **reported** for a human | keeps what the page shows before and after the backfill identical; the audit lists them |
| `emp_a41f` (4 hex) | 12 hex | 4 hex collides in a small company, and even 8 hex collides at ~50,000 employees (found in review) |
| Mapping table order | canonical order (pending, in progress, completed…) | matches the filter chips; one definition |
| Safeguards: 4 cards | + a sign-in/cookies card | the two extra features |
| Score cleared on moving to Pending | hidden, not cleared | destroying answers on a status change is irreversible |
| Backfill as a job (`BackfillStatusJob`) | a rake task + class | a person should run, watch and stop it; not fire-and-forget |

## 9. Trade-offs and what I would do next

- **Counts are exact, not cached.** Fine at 23 ms for 300k rows. If a tenant reaches tens of millions, add a short-TTL cache or a summary table, measured first.
- **Read-time score** costs four JSON lookups per displayed row (ten rows). If scores are ever needed for sorting or reporting across rows, a stored column becomes the right answer, and it can be backfilled with the same batching pattern.
- **Local storage in production is unsafe on ephemeral disks**; S3 is wired and documented but I could not test it without credentials.
- **The CAPTCHA** is the weakest control in the app against a determined attacker, especially with the accessible text alternative; rate limiting (per address and per account) and the generic error carry the weight.
- **Not done:** audit log of exports, per-admin permissions beyond "company admin", Loom video, mobile polish beyond a working responsive layout, internationalisation.

## 10. Build log: the steps and why each was done this way

Delivered as small, verified units, each in its own worktree and branch, committed with a Conventional Commit and merged only when its checks passed (`CHECKLIST.md` records it).

| # | Step | Commit(s) | Why it is done this way |
|---|---|---|---|
| 0 | Read the brief and the design bundle; build the checklist | `b4a107d` | Everything is traceable to a source before any code; the design file is the contract for the screens |
| 1 | Schema: companies, employees, assessments | `486468a` | Mirrors the legacy table (free-form nullable status, raw JSON) so the problems are real; models filter PII from `inspect`/logs from day one |
| 2 | `Status` + save-time normalisation | `667591d` | Task 3's write path first, because every later piece (filters, export, backfill, tester) reuses one definition |
| 3 | Sign-in, session, `Current.company` | `eaa026d` | The tenant rule (§3) has to exist before any feature that touches data |
| 4 | CAPTCHA | `0742613` | Requested extra; built before the UI so the sign-in page has something real to render |
| 5 | Cookie consent | `7fbee85` | Requested extra; a small PORO wrapping the cookie jar so it is unit-testable and the dashboard can use it |
| 6 | Seeds that reproduce the design exactly, plus legacy mess | `1096d46` | The design's numbers (64 rows: 6/10/29/14/5) become a regression fixture; deliberate dirty rows exercise every edge |
| 7 | App shell, sign-in page, cookie banner, design tokens | `271cde4` | Tokens come straight from the prototype; fonts are self-hosted (no third-party requests); removed an unused dependency with an npm advisory |
| 8 | Dashboard backend | `4bb011b`, `5575e26` | Two queries, only the shown columns, tenant-scoped, score rule (§5) |
| 9 | Dashboard UI + drawer | `fb0711f` | Verified against the design's screenshots in a real browser |
| 10 | Indexes + benchmark | `677ce9d` | Measure first; the data overturned the design's index suggestion |
| 11 | Log hygiene | `4f49082` | Tests read the real log; a mutation check proved they can fail |
| 12 | Export backend | `e00fceb` | Async (§4.1), redaction by construction, tenant-checked download |
| 13 | Export UI | `45a28bf`, `2f08a76` | Dialog + Exports page + polling only while something is in flight; fixed a parallel-test race it exposed |
| 14 | Guarded backfill | `1841d78`, `bfaf845` | Designed, tested, **not run**; SQL scripts kept out of `db/migrate`; fixed a libvips warning it exposed |
| 15 | Release plan page | `9e8f4ba` | Same data the code uses, a live tester that calls the real rules |
| 16 | Safeguards page | `617b261` | The "after" log line comes from the real filter |
| 17 | Production configuration | `6f7dba6`, `0486d21`, `ae56f36` | Verified by booting production mode; found and fixed a routing bug and a log leak |
| 18 | Docs and final audit | this commit | — |

**Defects found by testing, not by reading — all fixed:** the design's index not helping the page; a `TimeBudgetExceeded` constant that would have raised `NameError` in the job's `rescue` in production (Zeitwerk); Rails' loose boolean cast
granting cookie consent for `"yes please"`; the preview endpoint losing its date error to `valid?`; a half-applied migration that could not be reversed; a parallel test race on a cold Vite build; npm and Ruby warnings; a dev-only redirect that also ran in
production; the signed download link in the logs; and a CSP violation from Inertia's inline progress style (now a nonce).

## 11. How this was verified, and what was not

**Verified:** 180+ automated tests (tenancy, redaction, filters, score, status, backfill, auth, CAPTCHA, cookies, log contents); RuboCop, Brakeman (0 warnings, 1 documented false positive), bundler-audit and npm audit clean; TypeScript strict
with no errors; the Vite production build with no warnings; every screen exercised in a browser against the design's screenshots; production mode booted against a scratch single database (migrations, security headers, cookie flags, CSRF accepted and rejected,
an export built by a separate worker and downloaded, no PII in the file); mutation checks on the tenant scoping and the log filters.

**Not verified, so do not assume:** the Docker build (no Docker here); S3 storage (no credentials); a real Heroku deploy; behaviour on a production-sized table beyond the 300k/1.2M-row benchmark; the Loom video; any push to GitHub (this repository has no remote configured).
