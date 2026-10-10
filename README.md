# ErgoCheck — assessments admin

A company-admin console for ergonomic and health assessments, built as the answer to the
*"Safely extending a legacy Rails feature"* take-home. It does three things, all without rewrites:

| Task | What you get |
|---|---|
| **1. Company-scoped CSV export** | Export your own company's assessments with exactly two filters (date range, status). Built in the background; personal identifiers and free-text answers never leave the system. |
| **2. A faster dashboard with a correct score** | Server-side filtering and paging, two measured indexes, one grouped count instead of N+1 queries. Score is always the rounded average of four section scores, or an honest "Not scored yet". |
| **3. Status normalization** | New and updated records only ever hold `pending`, `in_progress`, `completed`, `needs_follow_up` or `archived`. The historical backfill is **designed, tested and guarded, but not executed**. |

Plus the two extras requested: a **self-hosted CAPTCHA** on sign-in and a **cookie-consent** feature.

- **Why it was built this way:** [`SOLUTION.md`](SOLUTION.md) (design, trade-offs, measured before/after, release and rollback plan, build log)
- **What is done:** [`CHECKLIST.md`](CHECKLIST.md) (every item ticked, mirrored in `.claude-checklist.json`)
- **How to ship it:** [`db/release_plan/RUNBOOK.md`](db/release_plan/RUNBOOK.md)

## Stack

Ruby 3.3 · Rails 8.1 · PostgreSQL · Inertia.js 3 · React 19 · TypeScript · Vite 8 · Tailwind CSS 4 ·
Active Storage · Solid Queue · Minitest.

## Run it locally

**Prerequisites:** Ruby 3.3.12, Node.js 22.12 or newer, PostgreSQL 14 or newer (running, with a role that can create databases).

```bash
bundle install
npm install
bin/rails db:setup      # creates the databases, loads the schema, seeds two demo companies
bin/dev                 # Rails on :3000 plus the Vite dev server
```

Open <http://localhost:3000>. `db:setup` prints the demo accounts and their password; to see them again run
`bin/rails db:seed`. There are two companies, so you can check tenant isolation by signing in as each.

Signing in needs the **verification code** from the image (it is a real, self-hosted CAPTCHA: type the five digits), or you can choose *Use a text question instead* (an accessible sum, e.g. "What is 36 minus 25?").
In development, background jobs run in-process, so exports complete without a separate worker.

### Quality gates (all expected to be clean)

```bash
bin/rails test           # 231 tests: tenancy, redaction, filters, score, status, backfill, auth, sessions, CAPTCHA, cookies, logs
bin/rubocop              # style
bin/brakeman             # static security analysis
bin/bundler-audit        # Ruby dependency advisories
npm run check            # TypeScript
npm audit                # JavaScript dependency advisories
bin/ci                   # all of the above in one go
```

### Measure the dashboard yourself

```bash
bin/rails perf:seed ROWS=100000      # one big tenant plus other tenants (3x as many rows)
bin/rails perf:benchmark             # legacy-style page vs the current one, with and without the indexes
bin/rails perf:explain               # EXPLAIN ANALYZE of the SQL the page really runs
bin/rails perf:clean                 # remove the benchmark data
```

My own run is committed in [`benchmarks/`](benchmarks/dashboard-2026-10-10.txt) and summarised in `SOLUTION.md`.

### The status backfill (plan only)

```bash
bin/rails status:backfill:report                 # read-only audit: safe at any time, even on production
bin/rails status:backfill:run CONFIRM=yes        # guarded; needs the status_legacy column (release step 3)
bin/rails status:backfill:rollback CONFIRM=yes   # restores the original values
```

The write tasks refuse to run without `CONFIRM=yes`, without the prerequisite column, and in production without
`BACKUP_TAKEN=yes`. This repository never runs them against real data.

## How it works

```
Browser (React + TypeScript, Inertia pages)
   │  sign in: password + CAPTCHA, encrypted session cookie
   ▼
ApplicationController ── Authentication ── Current.admin ── Current.company   ← the ONLY source of the tenant
   │
   ├─ AssessmentsController ── AssessmentDashboard ── 1 grouped COUNT + 1 page of 10 rows
   │        └─ AssessmentRow ── ScoreCalculator   (only the columns the page shows; never raw answers)
   │        └─ update ──────── Assessment (Status.normalize on save, unknown values rejected)
   │
   ├─ ExportsController ── AssessmentExport row ── AssessmentExportJob ── AssessmentExports::Builder
   │        preview/create/retry/download                │ batches of 1,000, progress saved, time budget
   │        (every lookup through Current.company)       ▼
   │                                              CSV in Active Storage ── 24-hour signed, one-minute links
   │
   ├─ ReleasePlansController ── ReleasePlan ── Status        (mapping, live tester, 8 steps, rollback)
   └─ SafeguardsController   ── Safeguards   ── real ParameterFilter output
```

### The steps an export goes through

1. **Request.** The admin picks a date range and status. A live preview shows how many rows match, counted by the
   same code that builds the file. The company is *never* read from the request.
2. **Queued.** A row is stored with only the two filters, and a job is enqueued with just its id. A company can have at
   most three exports in flight.
3. **Building.** The job claims the row atomically (so it can never run twice), reads the company's assessments in
   batches of 1,000, writes six columns to a temp file, and saves real progress after each batch. A time budget
   (`EXPORT_MAX_SECONDS`, default 300) stops a runaway export.
4. **Ready.** The file is attached to Active Storage; the link is valid for 24 hours. Downloading re-checks the
   tenant, then redirects to a **one-minute signed storage URL** (the file never streams through Rails).
5. **Failed or expired.** Failures store a generic code, never the exception message (which can contain row data).
   An expired export shows "Expired" and can be retried; a daily job deletes the stored files.

**What is in the file:** `assessment_id, employee_ref, department, status, score, created_at`.
**What is never in it:** names, e-mail addresses, free-text answers, raw responses. Employees appear as a one-way
HMAC reference such as `emp_a41f9c02d7e1`.

### Cookies

| Cookie | Purpose | Consent |
|---|---|---|
| `_ergocheck_session` | keeps you signed in (encrypted, HttpOnly, SameSite=Lax, Secure in production) | strictly necessary |
| `XSRF-TOKEN` | CSRF protection for in-page requests | strictly necessary |
| `ergocheck_consent` | remembers your choice (signed, 12 months) | strictly necessary |
| `ergocheck_prefs` | remembers the dashboard status filter and date preset (signed, 90 days) | **only with your opt-in** |

The banner offers *Accept all*, *Essential only* or *Customize*; **Cookie settings** in the sidebar reopens it.
Withdrawing consent deletes `ergocheck_prefs` immediately. The "release steps" ticks on the Release plan page use
`localStorage` and are likewise remembered only if you opted in.

### Where things live

| Area | Files |
|---|---|
| Tenancy and auth | `app/models/current.rb`, `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb` |
| CAPTCHA | `app/models/captcha.rb`, `app/models/captcha/renderer.rb`, `app/controllers/captchas_controller.rb` |
| Cookies | `app/models/cookie_preferences.rb`, `app/controllers/cookie_consents_controller.rb`, `app/javascript/components/CookieConsent.tsx` |
| Statuses | `app/models/status.rb`, `app/models/assessment.rb`, `app/models/status_backfill.rb`, `lib/tasks/status.rake`, `db/release_plan/` |
| Dashboard | `app/models/assessment_dashboard.rb`, `assessment_row.rb`, `score_calculator.rb`, `app/javascript/pages/assessments/` |
| Export | `app/models/assessment_export.rb`, `app/models/assessment_exports/`, `app/jobs/`, `app/controllers/exports_controller.rb`, `app/javascript/components/exports/` |
| Performance | `db/migrate/*_add_assessments_dashboard_indexes.rb`, `lib/tasks/perf.rake`, `benchmarks/` |
| Logging | `config/initializers/filter_parameter_logging.rb`, `test/integration/log_hygiene_test.rb` |

## Deploying to a Heroku-like platform

`Procfile` defines `web`, `worker` (Solid Queue, which builds exports) and `release` (`db:migrate`); `app.json` lists the
buildpacks (Node, then Ruby), the Postgres add-on and the environment. The database is a single `DATABASE_URL`: the job
queue and cache tables live in it too.

| Variable | Purpose |
|---|---|
| `RAILS_MASTER_KEY` | decrypts credentials |
| `DATABASE_URL` | set by the Postgres add-on |
| `ACTIVE_STORAGE_SERVICE=amazon` | **required on Heroku**, whose disk is ephemeral; plus `AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| `EXPORT_MAX_SECONDS` | time budget per export (default 300) |
| `SHOW_OPS_PAGES` | the Release plan and Safeguards pages are internal ops notes: hidden (404) in production unless this is `true` |
| `RAILS_LOG_LEVEL` | defaults to `info`; do not run production at `debug` with health data |

Production forces SSL, sends a strict Content-Security-Policy, never seeds demo accounts, refuses to boot on an ephemeral-disk platform without object storage configured, and does not route Active Storage's unauthenticated upload endpoints. The Dockerfile now builds
the Vite bundle, but I could not run a Docker build in my environment, so treat it as unverified.

## Demo script (5–10 minutes)

1. **Tenancy (1 min).** Sign in as Northwind: header says "Showing your company only". Sign out, sign in as Harbor & Pine:
   a different, smaller dataset. Mention the session, not a parameter, decides the company.
2. **Dashboard (2 min).** Chips with counts, presets, From/To, paging; open a row (the URL carries `?selected=`),
   change its status, watch the toast, the chip counts and the score react. Show a "Not scored yet" row and why.
3. **Export (3 min).** Export CSV from a filtered view: locked company, live match count, six columns, "Left out".
   Request it, watch progress, download, and open the file (no names, no e-mail). Show Exports page: ready, failed (Retry).
4. **Performance (1–2 min).** `bin/rails perf:benchmark` output, and the EXPLAIN difference between the design's index and the one shipped.
5. **Status plan (2 min).** Release plan page: type `comp`, `n/a`, `xyz` in the tester; walk the eight steps and which are live vs window;
   `bin/rails status:backfill:report`.
6. **Safeguards (1 min).** The before/after log line is produced by the real filter.
7. **Code tour.** `Current.company`, `AssessmentDashboard`, `AssessmentExports::Builder`, `Status`, `StatusBackfill`.
