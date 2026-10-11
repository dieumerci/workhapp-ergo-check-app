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
[`RAILWAY_SETUP.md`](RAILWAY_SETUP.md) (every variable and the step-by-step to host it) ·
[`SOLUTION.md`](SOLUTION.md) (design, trade-offs, measured before/after, release and rollback plan) ·
[`CHECKLIST.md`](CHECKLIST.md) (every item ticked) · [`db/release_plan/RUNBOOK.md`](db/release_plan/RUNBOOK.md) (how to ship the status change).

**Contents:** [Try it: demo sign-in](#try-it-demo-sign-in) · [Is it fully functional?](#is-it-fully-functional) ·
[Run it locally](#run-it-locally) · [Architecture](#architecture) · [Hosting on Railway](#hosting-on-railway) ·
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
bin/rails test           # 271 tests: tenancy, redaction, filters, score, status, backfill, auth, sessions, CAPTCHA, cookies, logs, new assessment, rate limits, production config
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

## Hosting on Railway

The app is set up to be hosted on [Railway](https://railway.com) as **one app service plus one PostgreSQL service**. The step-by-step
walkthrough and every variable are in [`RAILWAY_SETUP.md`](RAILWAY_SETUP.md); this section explains how the pieces fit.

> **Status, stated plainly:** the hosting configuration is written and checked, but I have **not deployed it to a live Railway project myself**
> (no Docker or Railway account in my environment). The owner's first deploy found a real bug, now fixed: the `production:` block in `config/database.yml` was commented out, so production only worked when `DATABASE_URL` was set, and the app now stops with a clear message when it isn't. What *was* tested: the same commands run locally in production mode (release build,
> `db:prepare db:seed`, `bin/rails server -b ::`, the job worker inside Puma, an export built and downloaded, the health check answering on IPv4 and IPv6),
> and `railway.json` is checked by a test against the rules in Railway's published schema. Expect to read the first deploy's logs.

### How it is hosted

```
 GitHub repository ──push──▶ Railway project
                              │
                              ├─ App service  (built from the Dockerfile, configured by railway.json)
                              │     1. build        Dockerfile: Ruby gems, Node only to compile the Vite/React bundle, assets precompiled
                              │     2. pre-deploy   bin/rails db:prepare db:seed     (creates/migrates tables; demo data only if allowed)
                              │     3. start        bin/rails server -b ::           (Puma; the job worker runs inside it)
                              │     4. health check GET /up must answer 200 before the new version takes traffic
                              │     └─ public URL   Settings → Networking → Generate Domain (HTTPS, handled by Railway)
                              │
                              ├─ Postgres service  ── DATABASE_URL (private network)   one database: app tables + job queue + cache
                              │
                              └─ Export files      Volume mounted at /rails/storage   (or S3-compatible storage)
```

- **One service runs everything.** Puma serves the app and, with `SOLID_QUEUE_IN_PUMA=1`, also runs the job worker that builds CSV exports. Jobs, cache and app data share the one Postgres, so there is no Redis to host.
- **The release is gated by the pre-deploy command.** Railway runs it in a separate container after the build and before the new version starts; if it fails, the deploy stops and the previous version stays live. `db:prepare` creates the tables on a fresh database and migrates an existing one; `db:seed` is safe to repeat and does nothing in production unless `ALLOW_DEMO_SEED=true`.
- **The health check protects each deploy.** Railway calls `/up` (from the host `healthcheck.railway.app`, which the app does not filter) and only switches traffic over once it answers with a success status.
- **HTTPS is terminated by Railway.** The app trusts that (`assume_ssl`), forces secure cookies, and sends a strict Content-Security-Policy.
- **Export files need storage that survives a deploy.** A container's disk is wiped on every deploy, so attach a Railway **Volume** at `/rails/storage` (simplest, one app replica) or use S3-compatible storage.
- **Secrets stay out of the repository.** Everything below is set as Railway variables, never committed. The demo password is the one value you must change before the URL is public.

### The variables you need

| Variable | Value | Needed |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (a reference to the Postgres service) | **yes** |
| `SECRET_KEY_BASE` | output of `bin/rails secret` | **yes** |
| `SOLID_QUEUE_IN_PUMA` | `1` | **yes**, or exports never get built |
| `ALLOW_DEMO_SEED` | `true` | for a demo with sample companies |
| `DEMO_ADMIN_PASSWORD` | a long password you choose | **yes** whenever `ALLOW_DEMO_SEED=true` |
| `SHOW_OPS_PAGES` | `true` | to show the Release plan and Safeguards pages |
| `PORT` | `3000` | recommended, pins the port the domain points at |
| `RAILWAY_RUN_UID` | `0` | only if you attach a Volume |

`RAILS_ENV=production` is already set inside the Dockerfile. The full list with explanations, the S3 variables, tuning options and
troubleshooting are in [`RAILWAY_SETUP.md`](RAILWAY_SETUP.md).

### Deploy in seven steps

1. **Push this repository to GitHub.**
2. In Railway: **New Project → Deploy from GitHub repo**, pick the repository. Railway finds the `Dockerfile` and reads [`railway.json`](railway.json). The first deploy stops with a missing-secret error until step 4. That is expected.
3. **Add the database:** **New → Database → Add PostgreSQL**.
4. Open the app service → **Variables**, and add the variables above (use the **Raw Editor** to paste them in one go).
5. **Storage:** create a **Volume** (⌘K or right-click the canvas), attach it to the app service and set its mount path to `/rails/storage`.
6. **Check the app service's Settings:** *Pre-deploy command* `bin/rails db:prepare db:seed`, *Start command* `bin/rails server -b ::` (or empty), *Builder* Dockerfile, *Healthcheck path* `/up`; and that **Variables** shows a real `DATABASE_URL` value. If the start command reads `bundle exec puma …`, that is the Heroku `Procfile`: replace it.
7. **Settings → Networking → Generate Domain**, open it, and sign in with a [demo account](#try-it-demo-sign-in).

**Changing or rolling back:** pushing to the connected branch deploys again. To go back, open the service's **Deployments** list, use the menu on an earlier deployment and choose **Rollback** (it restores the image and the variables).

If Railway ignores `railway.json` (its documentation now describes config-as-code as a legacy feature), set the same four things in the service **Settings**:
*Builder* = Dockerfile, *Pre-deploy command* = `bin/rails db:prepare db:seed`, *Start command* = `bin/rails server -b ::`, *Healthcheck path* = `/up`.

**The brief's release plan is written for a "Heroku-like" platform** (`heroku pg:backups`, `heroku run`). On Railway the same plan applies: take the backup with `pg_dump` against the database's connection string (enable the Postgres service's *Public Access* to reach it from your machine), restore it into a scratch database to prove it, and run the rake tasks inside the deployed service with `railway ssh`. A Heroku `Procfile` and `app.json` are included too.

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
