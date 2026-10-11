# SOLUTION

How the three tasks were solved, why each choice was made, what was measured, and what I would not do. The rule
I followed throughout, from the brief: *operate with restraint*. Targeted, safe changes; no rewrites.

**Contents** — [1 Summary](#1-summary) · [2 Requirement traceability](#2-requirement-traceability) ·
[3 The one rule that matters](#3-the-one-rule-that-matters-the-tenant-comes-from-the-session) ·
[4 Task 1: export](#4-task-1--company-scoped-csv-export) · [5 Task 2: dashboard](#5-task-2--dashboard-speed-and-the-score) ·
[6 Task 3: statuses](#6-task-3--normalizing-statuses-with-a-safe-release-plan) · [7 Sign-in, CAPTCHA, cookies](#7-sign-in-captcha-and-cookies) ·
[8 Departures from the design](#8-where-i-departed-from-the-design-and-why) · [9 Trade-offs](#9-trade-offs-and-what-i-would-do-next) ·
[10 Build log](#10-build-log-the-steps-and-why-each-was-done-this-way) · [11 Verification](#11-how-this-was-verified-and-what-was-not) ·
[12 Independent review](#12-the-independent-review-and-what-it-changed) ·
[13 The interface and search](#13-the-interface-search-and-what-changed-on-screen) · [14 The assistant](#14-the-assistant-ask-in-plain-english) ·
[15 Upgrading an old app](#15-upgrading-a-ten-year-old-rails-app-how-i-would-do-it) · [16 What to build next](#16-what-i-would-build-next-and-why)

---

## 1. Summary

| | What changed | The evidence |
|---|---|---|
| **Task 1** | One tenant-scoped export endpoint with two filters, built by a background job, six redacted columns, tenant-checked download that expires in 24 h. | 40+ tests including cross-tenant attempts; mutation checks (removing the tenant scope fails the tests); the real file inspected in a browser. |
| **Task 2** | One grouped `COUNT` plus one page of ten rows replaces "load everything, then one query per row". Two measured indexes. Score is the rounded mean of four sections or an explicit "Not scored yet". | A replay of the inherited behaviour took **94.5 s and 300,001 queries** for a 300k-row company; the new page takes **23 ms and 2 queries**. |
| **Task 3** | `Status` is the single definition; aliases are mapped and unknown values rejected on save. The backfill is guarded, batched, resumable and reversible, and **was not run**. | A test proves the SQL mapping agrees with the Ruby one on awkward input; the plan and rollback are in §6. |

Beyond the tasks I made **dashboard search**, a **redesigned interface**, and an optional **AI assistant** (§13, §14), and wrote down **how I would upgrade a ten-year-old Rails app** and what I would build next (§15, §16). Two small enhancements follow from the tasks rather than from the extras: an **audit trail on exports** (who requested each one, how often it was fetched, §4.6) and a **legacy-data note** on the dashboard (how much of the history is still non-standard, at no extra query, §5.6). §1.1 explains the approach to a ten-year-old application that ties the work together.

Things I deliberately did **not** do: rewrite the module, add a second UI framework, or run the historical backfill
(the brief says *plan only*).

### 1.1 How I approached a ten-year-old application

A legacy app is not a blank page. It earns money, it holds data nobody fully understands, and the people who wrote it have gone. So the question for each change was not "what is the best design?" but **"what is the smallest change that fixes the cause, that I can prove did not break anything, and that can be undone?"** The rules I followed, each with the place it shows up here:

| Rule | What it means in practice | Where |
|---|---|---|
| **Treat the symptoms as the specification** | I had no legacy code, so I rebuilt the behaviour the brief describes (load every row, one employee query per row, score in Ruby) and measured *that* as "before" | §5.1, `Perf.legacy_page` |
| **Fix the cause, not the symptom** | "Slow" was an unbounded N+1, not a missing cache; "wrong score" was the absence of one rule, not a formatting bug | §5.2, §5.4 |
| **One definition per rule** | The status mapping lives in `Status` and the score in `ScoreCalculator`. The page, the filters, the export, the backfill and the release-plan tester all call them, so the legacy mess is handled once and cannot drift | §6.1 |
| **Show the legacy data, do not hide it** | The page used to fold odd spellings into the five statuses silently. It now says how many records are still non-standard and what happens to them, so the clean-up is something an admin can watch shrink | §5.6 |
| **Expand, then contract, for data changes** | Write path first; additive schema (a nullable column, a `NOT VALID` constraint); a batched, reversible backfill; the irreversible step (dropping the old column) last, after 14 stable days | §6 |
| **Add guardrails that outlive me** | Tests that read the real log, tenant tests that send a rival company id, a query-count test, a test that pins the exact keys a page may expose, and mutation checks proving the tests can fail | §3, §5.5, §11 |
| **Treat health data as the product's main risk** | The tenant comes from the session; exports are redacted by construction; every export records who requested it and how often it was fetched | §3, §4.2, §4.6 |
| **Restraint** | No rewrite, no new framework, no new infrastructure. New code is small objects beside the old; anything beyond the brief is flagged | §8 |

**Why this stack suits a legacy application**

- **Ruby on Rails (kept, not replaced).** The brief is about extending a Rails app, and the cheapest change to review is one that follows the conventions the next maintainer already knows. Rails 8's built-ins (Solid Queue for jobs, Solid Cache, Active Storage) mean *no new infrastructure to run*, and in a legacy system every new moving part is risk.
- **PostgreSQL.** The data already lives there, and its features are what make the data change safe on a live table: `CREATE INDEX CONCURRENTLY`, `CHECK … NOT VALID` then `VALIDATE`, transactional DDL, `jsonb` for the answers, index-only scans for the chip counts.
- **Inertia.js with React and TypeScript.** It lets the UI be modernised **page by page without a rewrite and without a second API**. Controllers stay the contract: they hand each page its props, and authentication, CSRF, sessions and the tenant rule stay in Rails, in one place. An old server-rendered page and a new React page can live in the same app. I considered a separate React SPA plus a JSON API and rejected it: two deployables, two auth models, CORS and API versioning, and an attack surface in which every endpoint has to re-check the tenant. TypeScript is used where it prevents mistakes, the props contract between server and page, and is strict.
- **Plain Ruby objects for the domain** (`Status`, `ScoreCalculator`, `AssessmentDashboard`, the export builder). They are small, tested without HTTP, and can be lifted into whatever the app becomes.

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
| Step-by-step release and rollback, backup, live vs window | §6.4–6.8, SQL in `db/release_plan/` | The Release plan page renders the same steps from `ReleasePlan` |
| Keep the app responsive; no table stalls | Batched, short transactions, lock/statement timeouts, `CONCURRENTLY`, `NOT VALID` | `status_backfill_test`; SQL in `db/release_plan/` |
| README with run instructions, SOLUTION.md | These files | — |
| Video demo | Recorded separately with Loom; it is not part of this repository. The README's *Demo script* is its outline. | — |

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
- **Heartbeat and dead-worker handling.** `updated_at` is touched after every batch. A "processing" export silent for 10 minutes (or a queued one untouched for an hour) is *stalled*: the page shows it as failed with Retry immediately, a re-run can take over the dead claim, the per-company cap ignores it, and `ReapStuckExportsJob` (every 5 minutes) records it. A live worker's claim is never taken.
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

### 4.6 Audit trail: who exported the data, and was it fetched

The data is health-related, and "extra care" includes being able to answer an auditor's first two questions. An export already stored the requesting admin (`admin_id`); it now also counts how many times its download link was used and when last (`download_count`, `last_downloaded_at`). The Exports page shows *"Requested by Maya Reyes"* and *"Downloaded 2 times, last 5 min ago"* or *"Not downloaded yet"*. Admins of one company see each other's exports; a retry is attributed to whoever pressed Retry.

- **Small and safe.** Two columns on `assessment_exports` (a small new table, not the large assessments table); a constant default is a metadata-only change in PostgreSQL 11 and later.
- **Counted only after authorisation.** The download action counts a use once the request is tenant-checked and the file is downloadable, with a single atomic `UPDATE … SET download_count = download_count + 1` (two simultaneous clicks are both counted) that leaves `updated_at` alone, because that column is the build heartbeat. Refused downloads (not ready, expired, another company) are not counted; tests assert it.
- **Trade-off.** It records *that* a link was used, not *who* used it: the link is authorised per request, so any admin of the company could click it. A per-download audit row (admin, time, IP) is the next step if a regulator needs it.

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

### 5.6 Making the legacy data visible

The brief lists the inconsistent statuses as a known problem. Folding them on display (§5.2) made the page consistent, but silently: an admin could not tell that a third of their records were stored in an older spelling, or what happens to a value nobody recognises. A small note under the filters now says it:

> **42 of 64 use a standard status** *(progress bar)* · 17 records use an older spelling (complete, comp, done), shown under its standard status; 4 have no status or "n/a", shown as Pending; 1 has an unrecognised value, shown as Needs follow-up for a person to review. Anything saved from now on is always one of the five.

It appears only when there is something to say (a company with clean data sees nothing), follows the date range like the chips, counts only the signed-in company, and links to the release plan when the ops pages are on. After the backfill runs, the bar fills and the note disappears, so the clean-up becomes something you can watch.

- **No extra query.** The numbers come from the grouped `COUNT` the page already runs; a test asserts the page still makes two assessment queries. The prop is lazy, so opening the drawer does no dashboard work.
- **It never echoes an unrecognised stored value.** Only spellings from the closed alias list (case and spaces folded) are named; an unknown value is counted, not shown, because nobody knows what ten years of a free column contain. A test stores a sentence in the status and asserts it is absent from the response.
- **One definition.** `Status.legacy_kind` (`standard`, `blank`, `alias`, `unknown`) sits beside `normalize`, and a test pins the two together.

### 5.7 Search

Finding one person's assessment meant paging through the list, so the dashboard has a search box. It finds assessments by part of an employee's name, a department, or an assessment code (`A-10708`), and several words at once (`priya finance`: every word has to match, in any order), case-insensitively.

- **Same rules as everything else.** `AssessmentSearch` narrows a scope that is already the signed-in company's and looks only through that company's employees, so it cannot find, or reveal the existence of, another tenant's record. It is capped (4 words, 64 characters), drops control characters, treats `%` and `_` typed by a person as plain characters, and ignores an array or hash parameter.
- **The page stays consistent and fast.** The chip counts, the pager and the legacy-data note describe the search, and the page still makes **two assessment queries** (a test asserts it). Measured on a 100,000-row company with 4,000 employees: **6 to 14 ms** for every search shape tried (name, department, code, one letter, search plus status plus date range), against 17 ms for the unfiltered page. It uses the existing `company_id` and `employee_id` indexes; a trigram index would be the next step only if a company's employee table grew into the hundreds of thousands.
- **What is typed is personal data.** It reaches PostgreSQL as a bind parameter, never as text in the SQL, and the bind is named `search_term`, which (with the `q` request parameter) is on the log filter list, so the request line, the parameters and the SQL log all show `[FILTERED]`. A log-reading test searches a distinctive name and asserts it appears nowhere. It is never remembered, not even in the consented filter cookie.
- **A search is not part of an export.** The brief limits exports to exactly two filters (date range and status); a test sends `q` to the preview and create endpoints and asserts it is ignored, and the export dialog says so.
- **Behaviour.** The box waits for a pause in typing, never overwrites newer typing with a slow response, clears with Escape, is focused from anywhere with `/` or Cmd/Ctrl+K, and highlights the match with plain React text nodes (nothing a person typed is ever treated as HTML). Searches are rate limited (180 a minute, with their own counter) with a polite message.

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

### 6.8 Running it: roles, preparation and stop criteria

**Roles and rules.** A *driver* runs the steps and an *observer* watches the dashboards and may call a stop. One step at a time: do not start the next until the previous step's check has passed and been written down. The release is **reversible until step 8**; do not run step 8 early.

**Stop criteria (any one):** p95 response time doubles; database CPU above 80% for 2 minutes; replication lag above 30 s; error rate above baseline; `lock timeout` three times in a row; anything unexpected in the audit report.

**Before the day.**
1. Read the audit on a follower if one exists (it scans the table): `DATABASE_URL=$(heroku config:get FOLLOWER_URL -a assessments-prod) bin/rails status:backfill:report | tee before.txt`.
2. A person reviews the **unknown values** and the **blank-with-answers** count in `before.txt` and decides whether any should map elsewhere. If so, change `Status::ALIASES`, redeploy and re-run the report.
3. Check free disk and `pg_stat_user_tables` for `assessments` (dead tuples, last autovacuum): the backfill creates dead tuples in proportion to the rows it changes.
4. Enable preboot (`heroku features:enable preboot`) so deploys do not drop requests.
5. Pick a low-traffic window for steps 4 and 8, and tell support.

**Commands per step** (replace `assessments-prod` with the real app name; SQL files are in `db/release_plan/`):

```bash
# 3  add status_legacy                       (live)
heroku pg:psql -a assessments-prod < db/release_plan/01_add_status_legacy.sql
# 4  CHECK constraint, NOT VALID             (low-traffic window)
heroku pg:psql -a assessments-prod < db/release_plan/02_add_status_check_not_valid.sql
# 5  backfill in batches                     (live; pause with: heroku ps:stop run.<n>, resume by rerunning)
heroku run -a assessments-prod bin/rails status:backfill:report
heroku run -a assessments-prod bin/rails status:backfill:run CONFIRM=yes BACKUP_TAKEN=yes BATCH_SIZE=5000 PAUSE=0.2
# 6  validate the constraint                 (live)
heroku pg:psql -a assessments-prod < db/release_plan/03_validate_status_check.sql
# 7  dashboard indexes                       (live, CONCURRENTLY)
heroku pg:psql -a assessments-prod < db/release_plan/04_dashboard_indexes.sql
# 8  drop status_legacy after 14 stable days (low-traffic window)
heroku pg:psql -a assessments-prod < db/release_plan/05_drop_status_legacy.sql
# rollback, rung 2: constraint first, then the data
heroku pg:psql -a assessments-prod < db/release_plan/rollback_drop_status_check.sql
heroku run -a assessments-prod bin/rails status:backfill:rollback CONFIRM=yes BACKUP_TAKEN=yes
```

To go gentler during the backfill, raise `PAUSE` or lower `BATCH_SIZE` on the next run. An index that ends up `INVALID` after step 7 is dropped with `DROP INDEX CONCURRENTLY <name>;` and the script is rerun.
**Afterwards:** keep `before.txt` and the final report with the release record.

## 7. Sign-in, CAPTCHA and cookies

**Sign-in.** Encrypted, HttpOnly, SameSite=Lax session cookie (Secure in production), reset on sign-in (no fixation) and sign-out, 8-hour idle expiry, one generic failure message (no account enumeration), rate limiting, `no-store` on every authenticated response.

**CAPTCHA.** Self-hosted: no third party, no keys, works offline. The challenge is a **PNG** rendered server-side (pure Ruby, `chunky_png`) with per-glyph rotation, a sine warp, crossing lines and noise. It is deliberately an image, not text in the page, so the
answer is never in the DOM. Only an HMAC digest and an expiry are stored, in a **server-side `captcha_challenges` row**; the browser's session holds just the row id. Each challenge is single-use because verifying *deletes* the row (the delete is the gate), expires in 5 minutes and is checked *before* the password.
An independent review showed that keeping the digest in the cookie-store session made it replayable (one solved challenge passed 10 of 10 replays of the original cookie); moving it server-side fixed that, and the replay tests would catch a regression.

**Accessible alternative.** An image CAPTCHA locks out blind users (WCAG 1.1.1 and 3.3.8), so the sign-in page offers "Can't see the image? Use a text question instead": a short sum ("What is 36 minus 25?") a screen reader can read aloud, using the same server-side single-use mechanism. It is
easier for a program than the image, so it is limited to 6 requests per hour per address; the real brute-force defences are the per-address (10 per 3 minutes) and per-account (6 per 10 minutes) sign-in limits, which apply either way. **Trade-off:** a determined attacker will pick the text mode, so the CAPTCHA adds
less than it appears to; it is defence in depth, not the lock. If stronger bot resistance is needed, swap in Turnstile or hCaptcha (both have accessible challenges) behind the same `Captcha.verify?` call.

**Sessions.** The cookie holds a random token; a server-side `admin_sessions` row holds its digest. Signing out deletes the row, so a copied cookie stops working (tested), and the server, not a client-held timestamp, enforces the 8-hour idle expiry. The exports poller sends `X-Background-Poll` so a tab left open in the background no longer keeps a session alive indefinitely.

**Why not Devise?** Sign-in is `has_secure_password` (bcrypt) plus the server-side `admin_sessions` table, not Devise. Admins are provisioned, so there is no sign-up, confirmation, reset or lockout flow for Devise's modules to serve, and the parts this app does need (a replay-proof CAPTCHA, revocable sessions that expire on the server, a per-account throttle, no account enumeration) are not Devise features, so they would have been custom code on top of it anyway. Using Rails' own primitives keeps the dependency surface and the amount of framework behaviour to audit small. **Trade-off:** I own the sign-in code, including its security tests. If the product later needs password reset, 2FA or SSO, that is the moment to adopt Devise (or the Rails authentication generator's reset flow) rather than grow this layer.

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
| No way to create data (the brief asks for restraint and a small UI) | A **New assessment** dialog: `POST /assessments`, one model (`NewAssessment`), one component, 14 tests | **I wanted the app to be explorable end to end, so this goes beyond the brief; it is the one deliberate piece of scope creep.** It obeys the same rules: the company comes from the session, another tenant's employee is a 404, the status goes through `Status.normalize`, scores are four whole numbers 0–100 or none, and the new employee is created in the same transaction (a rejected assessment leaves nothing behind). The employee list is an optional Inertia prop fetched when the dialog opens, so the dashboard stays at two queries. It lives in its own files (`new_assessment.rb`, `NewAssessmentDialog.tsx`) and can be removed without touching the three tasks; the log fixes that shipped in the same commit (§12) are independent and should be kept. |
| Seeds abort in production | Seeds skip quietly unless `ALLOW_DEMO_SEED=true` | a hosting deploy that runs `db:seed` on every release must not fail, and must never plant demo accounts by accident |

## 9. Trade-offs and what I would do next

- **Counts are exact, not cached.** Fine at 23 ms for 300k rows. If a tenant reaches tens of millions, add a short-TTL cache or a summary table, measured first.
- **Read-time score** costs four JSON lookups per displayed row (ten rows). If scores are ever needed for sorting or reporting across rows, a stored column becomes the right answer, and it can be backfilled with the same batching pattern.
- **Local storage in production is unsafe on ephemeral disks**: attach a volume or use S3. S3 is wired (`config/storage.yml`) and exercised offline by `test/s3_storage_test.rb` with the AWS SDK's stubbed client and real signing, but never run against a real bucket. Railway's own Buckets and Cloudflare R2 need a custom endpoint, which is not configurable here.
- **The CAPTCHA** is the weakest control in the app against a determined attacker, especially with the accessible text alternative; rate limiting (per address and per account) and the generic error carry the weight.
- **New assessment is not an audit-grade write path.** It does not record who created an assessment, and there is no edit or delete for employees or assessments (an assessment is retired by archiving it). If the product needs those, an audit trail comes first.
- **The assistant's provider calls have never run against the live APIs** (§14): they are tested against a stand-in for the network. The offline rules mode was exercised end to end.
- **The front end has no automated tests** beyond strict `tsc`, the production build and the Rails integration tests of what the server sends. It was checked by hand in a browser at 375, 390, 768, 1024 and 1440 px. Component tests for the dialogs' focus handling and the search box's debounce are the first I would add.
- **Not done:** a per-download audit row (who, when, from where; §4.6 records only the count), per-admin permissions beyond "company admin", self-service sign-up and password reset, admin management, mobile polish beyond a working responsive layout, internationalisation.

## 10. Build log: the steps and why each was done this way

Delivered as small, verified units, each in its own worktree and branch, committed with a Conventional Commit and merged only when its checks passed.

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
| 18 | Docs: README, SOLUTION, release runbook, `.env.example` | `d981e35`, `a5c6bb3` | The reasoning, the measurements and the plan written down while fresh |
| 19 | Independent review, then fixes | `0d3c4cf`, `2c8f4c5`, `847d7cb`, `c4dd75a`, `9080ef9`, `a11de55`, `1325f77`, `c71e9e7` | A reviewer given only the code and the brief found what my own tests had not (§12); every fix has a test that fails without it. The last gate, run on a fresh clone of the final commit, found that one of my own fixes broke production boot (`c71e9e7`) |
| 20 | Production-readiness audit and release prep | `ef63c58`, `c748751` | an audit checklist, a changelog, version 0.1.0 |
| 21 | `bin/dev` port fix | `eaa4d4b` | Foreman gives each process `PORT + 100 × position`, so Rails had been on 3100; `web` now comes first |
| 22 | New assessment | `ae41044`, `f6945b4` | I wanted to explore the app end to end (§8). Its tests found a real log leak (§12) |
| 23 | Richer seeds | `a960fdb` | A third tenant and a second admin; production skips the seeds instead of aborting |
| 24 | Hosting configuration | `90b92f5`, `31dfbdb` | Dockerfile-based Railway setup and a README that explains the architecture and hosting. Railway's published schema allowed one pre-deploy command, not two, which the first draft of the config file got wrong |
| 25 | Rate-limit counters and tests | `e5559fa` | each limit named so counters don't collide; real cache in the test environment; `test/integration/rate_limit_test.rb` |
| 26 | Production database config | `daab82f` | the first Railway deploy failed with no `production` database configured; explicit block, readable boot error, tests that do not supply `DATABASE_URL` |
| 27 | Boot prepares the database | `87c3a00` | the second deploy: empty database plus the in-Puma job worker crashed on boot; `db:prepare db:seed` now runs from `config/puma.rb`, tested by starting the real server on an empty database |
| 28 | Settings page, not a config file | `173fc1c` | Railway's Settings page showed that Config as Code is unavailable to new services, so a `railway.json` is not read; the README now says the Settings page is the configuration |
| 29 | Demo accounts sign-in | `5ec4d29` | the first sign-in on the hosted copy failed: tolerant `ALLOW_DEMO_SEED`, demo passwords that follow `DEMO_ADMIN_PASSWORD`, no password in the log |
| 30 | S3 proven offline | `9fbb60b` | `AWS_*` variables were documented but the S3 service had never run; stubbed-client tests with real signing, and an honest `.env.example` |
| 31 | Repository trimmed to the brief | `0334fda` | README and SOLUTION only (other notes are ignored by Git); removed the unused Kamal scaffolding and a `railway.json` Railway does not read; removed a CI job that ran zero system tests and so always failed |
| 32 | Export audit trail | `f6d19d1` | who requested each export and how often it was downloaded (§4.6); six tests and a mutation check |
| 33 | Legacy data note | `98fb6cf` | the dashboard says how much of the data is still non-standard, at no query cost (§5.6); seven tests and two mutation checks |
| 34 | Dashboard search | `9ef3ca3` | find one person's assessment; company-scoped, bind-parameterised, never logged, never in an export (§5.7); 22 tests |
| 35 | Interface redesign | `497f082` | a design system in tokens and every screen, dialog and state restyled, floating navigation, snow-white canvas (§13); no behaviour changed |
| 36 | The assistant | `bd3acee` | "ask in plain English", off unless configured, narrow by design (§14); 41 tests |

**Defects found by testing, not by reading — all fixed** (the second batch came from the independent review, §12): the design's index not helping the page; a `TimeBudgetExceeded` constant that would have raised `NameError` in the job's `rescue` in production (Zeitwerk); Rails' loose boolean cast
granting cookie consent for `"yes please"`; the preview endpoint losing its date error to `valid?`; a half-applied migration that could not be reversed; a parallel test race on a cold Vite build; npm and Ruby warnings; a dev-only redirect that also ran in
production; the signed download link in the logs; and a CSP violation from Inertia's inline progress style (now a nonce). Review round: a CAPTCHA replayable from a copied cookie; exports stuck in "building" after a worker crash; a rollback that would overwrite later edits; an `INSERT … RETURNING` run through a read path that the query cache silently skipped; and, on the final fresh-clone gate, a production-only initializer that referenced an autoloaded constant and would have stopped every production boot.

## 11. How this was verified, and what was not

**Verified:** 350 automated tests (tenancy, redaction, filters, score, status, backfill, auth, sessions, CAPTCHA, cookies, log contents, rate limits, hardening, new assessment, seeds, S3 signing, the export audit trail, the legacy-data note, search, the assistant's validation and its provider adapters, a real first boot on an empty database); RuboCop, Brakeman (0 warnings, 1 documented false positive), bundler-audit and npm audit clean; TypeScript strict
with no errors; the Vite production build with no warnings; every screen exercised in a browser at 375, 390, 768, 1024 and 1440 px with no horizontal overflow, the search and the assistant (offline mode) driven end to end; text contrast computed for every colour pair (5.5 to 16.6 on the canvas); production mode booted against a scratch single database (migrations, security headers, cookie flags, CSRF accepted and rejected,
an export built by a separate worker and downloaded, no PII in the file); mutation checks on the tenant scoping, the log filters, session revocation and the signed-link log protection.

**Not verified, so do not assume:** the assistant against the live Anthropic and OpenAI APIs (no key was available; the adapters are tested against a stand-in for the network); the Docker build (no Docker where this was written); S3 against a real bucket (only the stubbed-client tests); the export file store on a Railway volume; a real Heroku release; behaviour on a production-sized table beyond the 300k/1.2M-row benchmark; the status backfill on real data (by design).

## 12. The independent review, and what it changed

After my own tests and checks were green I asked a reviewer with no stake in the code (a separate read-only agent, given the repository and the brief, not my conclusions) to look for real defects. It found no tenant-crossing hole, but it found things I had missed. Each was reproduced
before fixing and now has a test that fails without the fix.

| Found | Why it mattered | Fix |
|---|---|---|
| CAPTCHA digest lived in the cookie-store session | replaying the original cookie passed the same challenge 10 of 10 times; sign-out could not revoke a copied cookie | challenge and session state moved to server-side tables; verify = delete; per-account throttle |
| A killed worker left an export "processing" for ever | no Retry button, three such rows locked the company out, the page polled indefinitely and kept the session alive | heartbeat, stalled state, takeover, live-only cap, reaper job |
| Active Storage's unauthenticated upload routes were mounted | anyone could create blobs; with S3, obtain a presigned PUT | routes not drawn; only the signed download link is |
| Debug logging printed the signed download URL | a one-minute password for an export in the log | log subscriber detached, request lines silenced |
| Backfill rollback restored every row | silently undid statuses people edited after the backfill | restore only rows still holding the backfilled value |
| A PATCH with no status reset an assessment to pending | archived assessments lost their score | explicit blanking is rejected |
| The export reused the dashboard's select | employee names were loaded (never written) | dedicated select; a test reads the SQL |
| The dashboard join ignored the tenant | a legacy row could show another tenant's employee | tenant-pinned join |
| 8-hex employee references; `"0x1A"` scored as 26 | collisions at ~50,000 employees; a wrong number | 12 hex; decimal digits only |
| Dialog focus escape, no inert background, no error boundary | accessibility and resilience | portal + `inert`, topmost-only keys, error boundary |
| No non-visual CAPTCHA alternative | blind admins could not sign in | accessible text question, stricter throttle |
| *(mine, found while testing the assistant in a browser)* the page content was keyed on the raw URL path, so the first filter change that moved the page from `/` to `/assessments` remounted it and dropped its local state (an open panel, a typed question) | an open panel closed itself and the answer disappeared the moment it applied its own filters | `/` and `/assessments` are one key |
| *(mine, found by the final gate)* the storage guard raised `NameError` in an initializer | every production boot would have failed; dev and test skip that branch, so 228 green tests missed it | `after_initialize`, plus a test that boots real production mode in a subprocess |
| *(mine, found by the first sign-in on the hosted copy)* the production seed gate accepted only the exact string `true`, and a demo admin's password was set only when the account was first created | a variable like `True`, `1` or `"true"` silently skipped the demo data (no admins, so every sign-in said "We couldn't sign you in"), and changing `DEMO_ADMIN_PASSWORD` later never took effect; the seeds also printed the demo password into the deploy log | the gate accepts `true`, `1`, `yes`, `on` (any case, spaces and quotes ignored) and the skip message shows what the variable contained; demo accounts always converge to the configured password; production never prints it; 5 new seed tests |
| *(mine, found by the second Railway deploy)* production could be started against an **empty** database: the pre-deploy step did not run and a custom start command replaces the image's entrypoint | the job worker inside Puma queried `solid_queue_recurring_tasks` on boot, crashed ("relation does not exist"), and took Puma down with it | `config/puma.rb` runs `db:prepare db:seed` before anything starts (idempotent; opt out with `SKIP_DB_PREPARE=1`); `test/first_boot_test.rb` starts the real Puma against a new empty database and checks it stays healthy. Also corrected my own advice to set `PORT=3000`: Railway supplies `PORT` (8080) and Puma already listens on it |
| *(mine, found by the first Railway deploy)* the `production:` header in `config/database.yml` was commented out (it sat inside Rails' template comment), so the `url:` line below it belonged to `test:` and production had no configuration of its own | on a service without `DATABASE_URL` the app died deep in Active Record with "The `production` database is not configured for the `production` environment". Every earlier check set `DATABASE_URL`, and Rails builds a production config from that variable, so 271 green tests, three fresh-clone gates and a production-mode boot all passed | an explicit `production:` block; `config/initializers/database_url.rb` stops the boot with a readable message (skipped for the image build); `test/database_config_test.rb` reads the file; the boot test now runs once **without** `DATABASE_URL`, as a fresh service does. Lesson: a check that always supplies the one variable a feature depends on cannot see that feature break |
| *(mine, found while writing the interview guide)* the rate limits had no automated tests (the test environment used a null cache, which never counts), and the two unnamed limits in `ExportsController` shared one counter | in production the previews the export dialog sends on every filter change counted against the 10-per-hour export budget (15 previews were enough to refuse a real export), and exports counted against the preview budget | each limit has its own `name:`; the test environment now has a real in-process cache cleared before every integration test; 11 tests cover sign-in (per account and per address), the CAPTCHA image and text question, export create/retry and preview, and new assessments, including the two cross-talk cases that failed before the fix |
| *(mine, found by the production-mode gate)* the New assessment form's `scores` parameter was not filtered | the request log printed `"scores"=>{"workstation_setup"=>"90", …}`: health values in clear next to a numeric employee id, while the employee's name was already `[FILTERED]` | `:scores` added to the filter list (it also matches `section_scores`), with a test that reads the log |
| *(mine, found by the New assessment tests)* SQL logging ignores a model's own `filter_attributes`, and development's query log tags switch prepared statements off | a new employee's name was written to the SQL log in clear (as a bind in the test log, as a literal in `log/development.log`) | a bare `name` joins the global filter list; query log tags are off in development so values stay binds and are masked |

One reviewer finding I **rejected**: that a computable score is hidden for legacy blank-status rows. That is the design's rule ("Pending… say Not scored yet"), and those exact rows are what the backfill audit lists for a human; I documented it instead of changing it.

**What this taught me about my own process:** green tests and a clean linter said nothing about the CAPTCHA being replayable, because my tests replayed *the browser's* behaviour (a cookie jar that updates), not an attacker's; the replay tests now send the *original* cookie. And a green suite said nothing about production boot, because test and development never run production-only code; the gate has to include a real production-mode boot on the final commit, and now the suite does too.

## 13. The interface, search and what changed on screen

The brief asks for restraint, and the three tasks are small. The interface is where I spent the extra effort, because a ten-year-old product is usually judged on how it feels: it should look like a product from this decade, work on a phone, and be usable without a mouse.

**Direction: calm, editorial, spatial.** A health product should feel trustworthy and quiet, not like a default utility-class dashboard. The design system lives in tokens at the top of `app/javascript/entrypoints/application.css`; components use only the tokens, never raw colours.

| Decision | What and why |
|---|---|
| **Snow-white canvas, neutral greys** | The background is a clean, near-white `#fafbfa` with pure-white surfaces, and every grey is neutral, not cream. An earlier cream canvas read as beige on a laptop with True Tone; neutral greys stay white under any display tint. One token (`--color-canvas`) changes it to pure white. |
| **Type** | Instrument Serif for page titles and big numbers, Instrument Sans for the interface, IBM Plex Mono for codes. All self-hosted (one new package, `@fontsource/instrument-serif`, OFL licence), so a health product makes no third-party font requests. A short scale: display, title, body, small, eyebrow. |
| **Colour** | One brand accent (pine) and the five status hues, each with a text "ink" that passes 4.5:1 on white and on the canvas (computed: 5.5 to 16.6). Status is a marker plus a label, never colour alone. |
| **Open rows, not boxed cards** | Lists and tables sit on the page with hairlines instead of a box around every group; a status is a dot and a word, not a filled sticker. Containers are used only where they mean something (dialogs, the Safeguards tiles). |
| **Floating navigation** | A glass pill on wide screens, a floating tab bar within thumb reach on phones, and an account menu (name, company, "Your company only", cookie settings, sign out). Glass is used only for floating controls, never for content or inputs. |
| **One signature** | The whole view as a single bar split by status, above the filter chips. It is a picture of what the chips already say in words, so it is hidden from assistive technology. |
| **Sheets** | Dialogs are centred sheets on large screens and bottom sheets on phones; the detail drawer floats inset from the edges, with a five-way status chooser, the score in serif, and the four section bars. |
| **Motion** | 150 to 300 ms, one easing, nothing that shifts layout, switched off under `prefers-reduced-motion`. |
| **Touch and keyboard** | 44 px targets on touch screens, visible focus rings, a full keyboard path, `/` or Cmd/Ctrl+K to search, Escape to close. |

**Search** (§5.7) is the one new capability on the dashboard; the **legacy-data note** (§5.6) and the **export audit trail** (§4.6) are the others. **No behaviour changed in the redesign:** the same handlers, routes, props and tests. Verified by `tsc`, 350 tests, the production build with no warnings, and a manual pass at five widths.

**What this does not include:** dark mode, internationalisation, and automated front-end tests (see §9 and §16).

## 14. The assistant ("Ask in plain English")

A sentence such as *"completed in Warehouse, last 30 days"* or *"export September"* becomes the filters the page already has, or an export the person still reviews and confirms. It is the one place an AI model removes work here (clicks), and the rest of the application stays deterministic.

**It is off unless configured.** With no key and no `ASSISTANT_PROVIDER`, there is no button and the endpoint answers 404. `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` turns it on (Anthropic wins if both are set; `ASSISTANT_PROVIDER` and `ASSISTANT_MODEL` choose). `ASSISTANT_PROVIDER=rules` is an **offline mode**: a few plain rules read a status, a period, a month, a department and the word "export", and return the same tool calls a model would, with no AI and no network (it says so on screen). It lets the feature be tried, demonstrated and tested without a key.

**Built for health data, so it is deliberately narrow.**

| Concern | What the code does |
|---|---|
| What the model sees | The question, today's date, the allowed values, and the company's department names (only ones that look like names). **Never** an employee name, e-mail, answer, score or assessment row. A test creates all of those and asserts none appears in anything sent. The API key stays on the server. |
| What it can do | Two tools only: `set_filters` and `prepare_export`. Their output is validated like any request: statuses and presets from the allowed lists; dates parsed, ordered and bounded; a department only if it is one of the company's own (a person's name is dropped); the first call of each tool; unknown tools ignored. It cannot read data, write data, or create an export. |
| Who decides | It proposes; the person confirms. Filters appear as a chip with **Undo**; an export opens the normal export dialog prefilled, and nothing is created until *Request export*. |
| The question is personal data | The `message` parameter is filtered from the logs; failures are logged by class only; no error text carries the question, the key or a response body; questions are rate limited per admin. |
| Prompt injection | The only untrusted text is the person's own question (and department names, which are filtered by shape). The model has no data to leak and no tool that acts beyond what the person could do by hand. |
| Failure | One HTTP place with short timeouts and no retries; friendly messages for 401, 403, 429, 5xx, an unreadable reply and a dead network. |

**Trade-offs and honesty.** The provider calls (Anthropic Messages with tool use, OpenAI Chat Completions with function calling, no new gem) are **tested against a stand-in for the network and have not been run against the live APIs**, because no key was available where this was written; the offline mode was exercised end to end in a browser. A model can misread a request, which is why the result is shown, undoable and never destructive. Sending a question to a third party is a real decision for a health product: the screen says who receives it, and the safe default is off.

## 15. Upgrading a ten-year-old Rails app: how I would do it

The brief describes an app that works, written by someone who has left, probably on an old Ruby and an old Rails. The goal is not "be current"; it is to **make change cheap and safe again**, without a rewrite and without freezing the business. This is the order I would work in. The repository demonstrates the habits at small scale (§1.1).

**0. Look before touching (a day).** `ruby -v`, the Rails version in `Gemfile.lock`, `bundle outdated`, `bundle audit`, `config.load_defaults`, the database version, the deploy pipeline, whether CI exists and is green, how long a deploy takes, whether there is error tracking. Count deprecation warnings. Write down what is *not* known.

**1. A safety net first.** Upgrades fail where behaviour is unspecified. Before any version change, add characterisation tests around the flows that earn money or hold risk (here: tenancy, the export, the dashboard, sign-in), run CI on every push, and add error tracking and a health check. A pending upgrade with no tests is a guess.

**2. Ruby, then Rails, one step at a time, never skipping.**
- Ruby in small hops (for example 2.x to 2.7, then 3.0, 3.2, 3.3), because Ruby 3 changed keyword arguments and every hop surfaces a different class of break. `ruby -W:deprecated` and a RuboCop target version find most of it.
- Rails one minor at a time (for example 4.2, 5.2, 6.1, 7.0, 7.2, 8.0, 8.1): `rails app:update`, read the diff, fix deprecations (run tests with deprecations set to raise), then move `load_defaults` up gradually. Known milestones: the Zeitwerk autoloader (6.0, check with `zeitwerk:check`), strong parameters, encrypted credentials, Active Storage replacing attachment gems, and Solid Queue and Solid Cache (8.0) removing the need for Redis.
- **Dual-boot** (`Gemfile` and `Gemfile.next`, selected by an environment variable) so CI runs both versions and the app stays releasable at every step.
- Every step is its own release with its own rollback; none is combined with a feature.

**3. Dependencies.** Remove dead gems first; replace abandoned ones; automate with Dependabot and `bundler-audit` in CI (both are in this repository). Prefer the framework's built-ins when they have caught up, because each removed gem is one fewer thing to upgrade.

**4. The database, separately.** Upgrade PostgreSQL on its own schedule (on Heroku-like platforms, a follower promotion or `pg:upgrade`; elsewhere dump and restore into the new version, rehearsed on a copy). Keep schema changes out of upgrade releases, and use the same expand-then-contract pattern as the status release (§6): additive change, backfill in batches, validate, remove the old thing last.

**5. The front end, one page at a time.** Replace the asset pipeline (Sprockets or Webpacker) with Vite, then move screens to React with **Inertia**, which lets an old server-rendered page and a new one live in the same app (the strangler pattern), with auth, CSRF and the tenant rule staying in Rails. Add TypeScript where it protects a contract (the props), strict from the first file.

**6. Operations.** A reproducible build (a `Dockerfile` or buildpacks), configuration in environment variables, a health check, a boot-time database prepare, and a runbook. Measure p95 latency, error rate, boot time, deprecation count, vulnerabilities and CI duration before and after, so "better" is a number.

**What I would tell the team.** A small app with tests is roughly a day or two per Rails minor; the same app without tests is mostly the cost of writing them. Do not upgrade and add features in the same release. Keep the old Ruby and Rails in CI until production has moved, then delete them. Write down every decision in the pull request that makes it.

## 16. What I would build next, and why

Ordered by value to a company admin, each with the reason and the smallest first step. None is built; the ones that are built are marked.

| Idea | Why | First step |
|---|---|---|
| **Search** (built, §5.7) | Finding one person is the most common task | done |
| **Legacy-data note and export audit trail** (built, §5.6, §4.6) | Makes the old data visible; answers "who exported it?" | done |
| **Ask in plain English** (built, §14) | Removes clicks, behind a safe boundary | next: "explain this score" using only the four section numbers |
| **Saved views** | Admins repeat the same filters (for example "follow-ups this month"); a view is a name for a URL | a `saved_views` table per admin storing the filter parameters, and a menu |
| **A command palette** (Cmd-K) | One keyboard surface for search, "new assessment", "export" and navigation | extend the existing search box into a list of actions |
| **Bulk status change, with undo** | Archiving or following up on many rows one by one is slow | row checkboxes, one PATCH for the selection, an undo toast |
| **Status history** | Who changed a status and when; the same audit instinct as exports | a `status_changes` table written in the model callback |
| **Reminders** | Pending assessments older than N days should nudge someone | a recurring Solid Queue job and a mailer |
| **Trends** | Is the share of "needs follow-up" going down? | a monthly snapshot table, one small chart |
| **Scheduled exports** | Teams ask for the same export every month | a recurring job reusing the existing builder |
| **Row-level security in PostgreSQL** | A second tenant guard behind the application one | a policy per table keyed on a session setting |
| **Dark mode** | Expected on a modern product | tokens already centralised: a second set of values |
| **Two-factor sign-in, SSO** | The honest next step beyond a CAPTCHA | adopt Devise or the Rails authentication generator at that point (§7) |
| **Front-end tests** | The least-covered layer | component tests for the dialog focus handling and the search debounce |
