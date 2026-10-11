# ErgoCheck — assessments admin

A multi-tenant console where a company's admins review their employees' ergonomic and health assessments and export them safely.
It is built as the answer to the *"Safely extending a legacy Rails feature"* take-home, which asks for three targeted changes to an
old Rails app, without rewrites:

| Task | What you get |
|---|---|
| **1. Company-scoped CSV export** | Export your own company's assessments with exactly two filters (date range, status). Built in the background; personal identifiers and free-text answers never leave the system. |
| **2. A faster dashboard with a correct score** | Server-side filtering and paging, two measured indexes, one grouped count instead of N+1 queries. Score is always the rounded average of four section scores, or an honest "Not scored yet". |
| **3. Status normalization** | New and updated records only ever hold `pending`, `in_progress`, `completed`, `needs_follow_up` or `archived`. The historical backfill is **designed, tested and guarded, but not executed**. |

Plus the extras the owner asked for: a **self-hosted CAPTCHA** on sign-in, a **cookie-consent** feature, and a small
**New assessment** form so the app can be explored end to end.

**Read next:** [`APP_GUIDE.md`](APP_GUIDE.md) (a plain-language tour: screens, how to run, troubleshooting) ·
[`SOLUTION.md`](SOLUTION.md) (design, trade-offs, measured before/after, release and rollback plan) ·
[`CHECKLIST.md`](CHECKLIST.md) (every item ticked) · [`db/release_plan/RUNBOOK.md`](db/release_plan/RUNBOOK.md) (how to ship the status change).

**Contents:** [Try it: demo sign-in](#try-it-demo-sign-in) · [Is it fully functional?](#is-it-fully-functional) ·
[Run it locally](#run-it-locally) · [Architecture](#architecture) · [Deploy on Railway](#deploy-on-railway) ·
[Quality gates](#quality-gates) · [Demo script](#demo-script-510-minutes)

## Stack

Ruby 3.3 · Rails 8.1 · PostgreSQL · Inertia.js 3 · React 19 · TypeScript · Vite 8 · Tailwind CSS 4 ·
Active Storage · Solid Queue · Minitest.

## Try it: demo sign-in

After `bin/rails db:setup` (or `bin/rails db:seed`) these four company admins exist. **They all share one password.**

| Email | Company | Data |
|---|---|---|
| `maya.reyes@northwind.example` | Northwind Logistics | 64 assessments (the design's dataset, with legacy-messy statuses) |
| `daniel.osei@northwind.example` | Northwind Logistics | the same company as Maya, a second admin |
| `jonas.weber@harborpine.example` | Harbor & Pine Clinics | 24 assessments |
| `aisha.bello@summitphysio.example` | Summit Physio Group | 40 assessments (with legacy-messy statuses) |

**Password: `ergocheck-demo-2026`** (change it before seeding with `DEMO_ADMIN_PASSWORD=...`; on any hosted copy, always do).

**Signing in has three parts:** email, password, then the **verification**. It is a real self-hosted CAPTCHA: type the five digits in the
image. If you cannot read it, click *Can't see the image? Use a text question instead* and answer the sum (for example "What is 36 minus 25?").
A wrong code is rejected even with the right password, and every challenge works once.

**What to try:** sign in as Maya and as Jonas in turn and see two different datasets (the page says *Showing your company only*; the
company comes from your session, never from a parameter). Then use the dashboard, open a row, change its status, press **New assessment**, and export a CSV.
The [demo script](#demo-script-510-minutes) below is a ready-made tour.

## Is it fully functional?

**Yes, for what the brief and the design describe.** Every screen works against a real database; nothing is mocked.

| Area | What works |
|---|---|
| Sign-in / sign-out | Password + CAPTCHA, server-side sessions that expire after 8 idle hours, rate limits, one generic error message |
| Dashboard | Status chips with live counts, 7/30/90-day and custom date filters, paging, a detail drawer (`?selected=`), the score and its four sections |
| Change status | From the drawer. Aliases such as `comp` are normalized, unknown values are rejected, and the counts and score update immediately |
| **New assessment** | Pick one of your employees or add one, choose a status, optionally enter the four section scores. Saved to your company only |
| CSV export | Live match count, background build with real progress, ready / failed / expired states, retry, one-minute signed download. Six columns, no personal data |
| Exports page | History of the company's exports and their state |
| Cookies | Consent banner, *Cookie settings*, an optional cookie only after opt-in |
| Release plan and Safeguards | Internal pages: the status mapping with a live tester, the eight release steps, and the log-filtering proof |

**Deliberately not included** (they are outside the brief, and the brief asks for restraint): self-service sign-up, password reset and e-mail (there is no
mailer), admin management, editing or deleting employees and assessments (an assessment is retired by setting it to *Archived*), and running the
historical status backfill (the brief says *plan only*). Admin accounts are provisioned (the seeds do it).

**Why not Devise?** Sign-in is a small custom layer on Rails' own tools: `has_secure_password` (bcrypt) plus server-side `admin_sessions` rows.
The app needs no sign-up, confirmation, reset or lockout flows, so Devise's modules would be unused surface, and the CAPTCHA, the revocable
sessions and the per-account throttle all had to be custom anyway. The cost is real: if the product later needs password reset or 2FA, adopting Devise
(or the Rails authentication generator's reset flow) is the sensible next step. Details in [`SOLUTION.md` §7](SOLUTION.md#7-sign-in-captcha-and-cookies).

## Run it locally

**Prerequisites:** Ruby 3.3.12, Node.js 22.12 or newer, PostgreSQL 14 or newer (running, with a role that can create databases).

```bash
bundle install
npm install
bin/rails db:setup      # creates the databases, loads the schema, seeds the demo companies
bin/dev                 # Rails on :3000 plus the Vite dev server on :3036
```

Open <http://localhost:3000> and sign in with an account from [the table above](#try-it-demo-sign-in).
`db:setup` prints the accounts again; so does `bin/rails db:seed` at any time (it never duplicates anything).

**Port 3000 already used?** Pick another one; Rails follows `PORT`:

```bash
PORT=4000 bin/dev                          # open http://localhost:4000
PORT=4000 VITE_RUBY_PORT=3046 bin/dev      # also move Vite, if 3036 is taken too
```

In development, background jobs run in-process, so exports finish without a separate worker.
More help (Postgres not running, a blank page, the CAPTCHA) is in [`APP_GUIDE.md`](APP_GUIDE.md#troubleshooting).

### Quality gates

All of these are expected to be clean:

```bash
bin/rails test           # 248 tests: tenancy, redaction, filters, score, status, backfill, auth, sessions, CAPTCHA, cookies, logs, new assessment
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

## Architecture

### The big picture

```
 Browser  ── React 19 + TypeScript pages, rendered by Inertia (no separate API: Rails hands each page its props)
    │
    ▼
 Rails 8.1 (one app, one deployable)
    │   ApplicationController ── Authentication ── Current.admin ── Current.company   ← the ONLY source of the tenant
    │
    ├─ SessionsController, CaptchasController, CookieConsentsController     sign-in, CAPTCHA, consent
    ├─ AssessmentsController   index (dashboard) · create (new assessment) · update (status)
    │       ├─ AssessmentDashboard ── 1 grouped COUNT + 1 page of 10 rows ── AssessmentRow ── ScoreCalculator
    │       └─ NewAssessment · Assessment ── Status.normalize on save, unknown values rejected
    ├─ ExportsController ── AssessmentExport row ──enqueue──▶ AssessmentExportJob ── AssessmentExports::Builder
    │                                                              │ batches of 1,000, progress saved, time budget
    │                                                              ▼
    │                                                    CSV in Active Storage ── signed, one-minute download links
    └─ ReleasePlansController, SafeguardsController   internal ops pages (hidden in production unless SHOW_OPS_PAGES)
    │
    ▼
 PostgreSQL  ── one database: app tables + Solid Queue (jobs) + Solid Cache
```

### Why it is shaped this way

- **Inertia, not a separate SPA and API.** One repository, one deploy, one set of auth and CSRF rules. Controllers return page props; React renders them. TypeScript stays small and sits where it adds value (the dashboard, the dialogs, the export UI).
- **The tenant comes from the session, never from the request.** `Current.company` is derived from the signed-in admin, and every query goes through `Current.company.<association>`. A
  `company_id` parameter is simply not read anywhere. Another company's record is a 404, not a 403, so it does not even confirm that it exists.
- **Plain Ruby objects for the domain.** `Status`, `ScoreCalculator`, `AssessmentDashboard`, `AssessmentRow`, `NewAssessment` and the export builder are small, individually tested classes. Controllers only translate HTTP to and from them.
- **Background export, not streaming.** A large export can outlast a web request, and a dyno restart should not lose it. A queued row plus a job gives progress, retry and a stored file; the reasoning is in [`SOLUTION.md` §4.1](SOLUTION.md#41-async-not-streaming--and-why).
- **Redaction by construction.** The export reads six columns through a dedicated select. Names, e-mails and free text are never loaded, so they cannot leak by a missed filter.
- **Jobs live in the same Postgres.** Solid Queue and Solid Cache use tables in the one database, so a deployment needs only Postgres (no Redis).

### Data model

```
companies 1───* admins            (name, email, password_digest)   ── admin_sessions (server-side sessions)
          1───* employees         (name, email, department)
          1───* assessments ◀──── employee_id        (status, responses_json, created_at)
          1───* assessment_exports (filters, state, progress, file)
captcha_challenges                (single-use digest + expiry; verifying deletes the row)
```

`assessments.status` is a free string with years of inconsistent values; that is the legacy rough edge the brief describes. Reads normalize through `Status.classify`, writes through `Status.normalize`.
Indexes: `(company_id, created_at DESC, id DESC)` orders the page, `(company_id, status, created_at DESC)` answers the status counts.

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
| New assessment | `app/models/new_assessment.rb`, `AssessmentsController#create`, `app/javascript/components/assessments/NewAssessmentDialog.tsx` |
| Export | `app/models/assessment_export.rb`, `app/models/assessment_exports/`, `app/jobs/`, `app/controllers/exports_controller.rb`, `app/javascript/components/exports/` |
| Performance | `db/migrate/*_add_assessments_dashboard_indexes.rb`, `lib/tasks/perf.rake`, `benchmarks/` |
| Logging | `config/initializers/filter_parameter_logging.rb`, `test/integration/log_hygiene_test.rb` |
| Deployment | `Dockerfile`, `railway.json`, `Procfile`, `app.json`, `bin/docker-entrypoint` |

## Deploy on Railway

The repository is ready for [Railway](https://railway.com): the `Dockerfile` builds the app (including the Vite bundle) and
[`railway.json`](railway.json) tells Railway to use it, run the database steps **before** each release, check `/up`, and restart on failure.

> **Honesty note:** I could not run Docker or a Railway deployment from my environment, so this path has not been executed end to end. The commands and variables below come from
> Railway's documentation and the app's own production-mode boot, which I did test locally. Expect to read the first deploy's logs.

**Steps**

1. **Push this repository to GitHub.**
2. In Railway: **New Project → Deploy from GitHub repo** and pick the repository. Railway sees the `Dockerfile` and `railway.json`.
3. **Add the database:** in the project, **New → Database → Add PostgreSQL**.
4. Open the app service → **Variables**, and add:

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (a reference to the database service; use its name if you renamed it) |
   | `SECRET_KEY_BASE` | the output of `bin/rails secret` (any long random string) |
   | `SOLID_QUEUE_IN_PUMA` | `1`, so the one service also runs the job worker that builds exports |
   | `ALLOW_DEMO_SEED` | `true`, to load the demo companies on deploy (seeds are skipped in production otherwise) |
   | `DEMO_ADMIN_PASSWORD` | **a password you choose.** Never leave the documented demo one on a public URL |
   | `SHOW_OPS_PAGES` | `true`, so the Release plan and Safeguards pages show (they are 404 in production by default) |

5. **Where exports are stored.** Export files are written through Active Storage. Railway's container disk is wiped on every deploy, so choose one:
   - *Quick demo:* attach a **Volume** to the service mounted at `/rails/storage`, and set `RAILWAY_RUN_UID=0` (the image runs as a non-root user, which cannot write to a fresh volume otherwise). A volume allows one replica and a redeploy has a short downtime.
   - *Better:* S3-compatible storage. Set `ACTIVE_STORAGE_SERVICE=amazon`, `AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION` (a private bucket).
6. **Settings → Networking → Generate Domain.** Open it and sign in with a [demo account](#try-it-demo-sign-in).

**What happens on each deploy:** Railway builds the image; before starting it runs `bin/rails db:prepare` (creates or migrates the tables) and `bin/rails db:seed`
(idempotent, and a no-op unless `ALLOW_DEMO_SEED=true`); then it starts `bin/rails server -b ::` and waits for `/up` to answer 200.

If Railway ignores `railway.json` (its docs now mark config-as-code as a legacy feature), set the same values in the service **Settings**: *Builder* = Dockerfile,
*Pre-deploy command* = `bin/rails db:prepare && bin/rails db:seed`, *Start command* = `bin/rails server -b ::`, *Healthcheck path* = `/up`.

| Other variable | Purpose |
|---|---|
| `EXPORT_MAX_SECONDS` | time budget per export (default 300) |
| `RAILS_LOG_LEVEL` | defaults to `info`; never run production at `debug` with health data |
| `RAILS_MASTER_KEY` | only if you use encrypted credentials instead of `SECRET_KEY_BASE` |

Production forces SSL, sends a strict Content-Security-Policy, never seeds demo accounts unless you opt in, refuses to boot on Heroku's ephemeral disk without object storage, and does not route Active Storage's unauthenticated upload endpoints.

**The brief's release plan is written for a "Heroku-like" platform** (`heroku pg:backups`, `heroku run`). On Railway the same plan applies: take the backup with `pg_dump` against the database's connection string, restore into a scratch database to prove it, and run the rake tasks with `railway run` or in a one-off shell. A Heroku `Procfile` and `app.json` are included too.

## Demo script (5–10 minutes)

1. **Tenancy (1 min).** Sign in as Northwind (Maya): header says "Showing your company only". Sign out, sign in as Harbor & Pine (Jonas):
   a different, smaller dataset. Mention the session, not a parameter, decides the company.
2. **Dashboard (2 min).** Chips with counts, presets, From/To, paging; open a row (the URL carries `?selected=`),
   change its status, watch the toast, the chip counts and the score react. Show a "Not scored yet" row and why.
3. **New assessment (1 min).** Press *New assessment*, add an employee, choose *Completed*, enter four scores, create it, and see the score the dashboard computes.
4. **Export (3 min).** Export CSV from a filtered view: locked company, live match count, six columns, "Left out".
   Request it, watch progress, download, and open the file (no names, no e-mail). Show the Exports page: ready, failed (Retry).
5. **Performance (1–2 min).** `bin/rails perf:benchmark` output, and the EXPLAIN difference between the design's index and the one shipped.
6. **Status plan (2 min).** Release plan page: type `comp`, `n/a`, `xyz` in the tester; walk the eight steps and which are live vs window;
   `bin/rails status:backfill:report`.
7. **Safeguards (1 min).** The before/after log line is produced by the real filter.
8. **Code tour.** `Current.company`, `AssessmentDashboard`, `AssessmentExports::Builder`, `Status`, `StatusBackfill`.
