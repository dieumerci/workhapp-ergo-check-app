# ErgoCheck: the app guide

A plain-language tour of what the app is, how to run it, what each screen does, and what to do when something goes wrong.
For the engineering reasoning (design, trade-offs, measurements) read [`SOLUTION.md`](SOLUTION.md); for the short version and the deployment steps, [`README.md`](README.md).

## 1. What ErgoCheck is

Companies run ergonomic and health assessments for their employees (workstation set-up, posture, breaks, discomfort). **ErgoCheck is the admin console for that data.**
A *company admin* signs in and sees only their own company's assessments. They can:

- browse and filter assessments, and see each one's **ergonomic score** (the rounded average of four section scores);
- change an assessment's **status** (`pending`, `in_progress`, `completed`, `needs_follow_up`, `archived`);
- **add a new assessment** for one of their employees;
- **export** their assessments to CSV, with names, e-mail addresses and free-text answers deliberately left out.

It is health-related, multi-tenant data, so two rules shape everything: **a company can never see or export another company's data**, and **personal or health details never reach logs or exports**.

The app was built to answer a take-home called *"Safely extending a legacy Rails feature"*: a secure export (Task 1), a faster dashboard with a correct score (Task 2), and a safe plan to clean up messy status values (Task 3).

## 2. Run it in five minutes

You need **Ruby 3.3.12**, **Node.js 22.12+** and **PostgreSQL 14+** running locally.

```bash
bundle install
npm install
bin/rails db:setup        # creates the databases, loads the schema, adds the demo data
bin/dev                   # starts Rails and the Vite dev server
```

Open <http://localhost:3000>. **To use another port**, set `PORT`:

```bash
PORT=4000 bin/dev                       # then open http://localhost:4000
PORT=4000 VITE_RUBY_PORT=3046 bin/dev   # if the Vite port (3036) is also taken
```

### Signing in

| Email | Company |
|---|---|
| `maya.reyes@northwind.example` | Northwind Logistics (64 assessments) |
| `daniel.osei@northwind.example` | Northwind Logistics (a second admin of the same company) |
| `jonas.weber@harborpine.example` | Harbor & Pine Clinics (24 assessments) |
| `aisha.bello@summitphysio.example` | Summit Physio Group (40 assessments) |

Password for all four: **`ergocheck-demo-2026`**.

After the email and password there is a **verification step**. Type the five digits shown in the image. If you cannot read it, choose *Can't see the image? Use a text question instead* and answer the little sum.
Codes work once and expire after five minutes, so if one fails, just type the new one.

## 3. A tour of the screens

| Screen | What it does |
|---|---|
| **Sign in** | Email, password and the verification. A banner at the bottom asks about cookies on your first visit. |
| **Assessments** (home) | The company's assessments, ten per page. Chips filter by status and show live counts; *7 / 30 / 90 days / All time* and the From/To dates filter by date. The status and period you choose are remembered only if you accepted optional cookies. |
| **Detail drawer** | Click a row. Shows the employee, department, an anonymous employee reference (`emp_…`), the status (changeable) and the score with its four sections. Free-text answers are never shown. |
| **New assessment** | The button above the table. Choose an employee, or *+ Add a new employee…* (name and optional department), choose a status, and for a completed, needs-follow-up or archived assessment optionally enter the four section scores (0 to 100, all four or none). After saving, its drawer opens. |
| **Export CSV** | Choose a date range and status. The dialog tells you how many rows match, builds the file in the background with a progress bar, then offers *Download CSV*. |
| **Exports** | The company's recent exports and their state: building, ready, failed (with *Retry*) or expired. |
| **Release plan** | Internal page about the status clean-up: the mapping of old values to the five new ones, a live tester, and the eight release steps. *Plan only*: nothing here changes data. |
| **Safeguards** | Internal page showing what is kept out of logs, produced by the app's real log filter. |
| **Cookie settings** (sidebar) | Reopens the consent choices. Withdrawing consent deletes the optional cookie immediately. |

The two internal pages are visible in development. In production they return 404 unless `SHOW_OPS_PAGES=true`.

### What the CSV contains

`assessment_id, employee_ref, department, status, score, created_at`. No names, no e-mail addresses, no answers. The employee appears as a one-way reference such as `emp_a41f9c02d7e1`, so rows for the same person line up without identifying them.

## 4. How the pieces fit

```
 Browser (React + TypeScript, rendered by Inertia)
    │
 Rails 8.1 ── who is signed in ──▶ Current.admin ──▶ Current.company   (the only source of "which company")
    ├─ Assessments page ── one grouped count + one page of ten rows
    ├─ New assessment / status change ── Status rules: five values only
    ├─ Exports ── a queued row ──▶ background job ──▶ CSV file ──▶ signed one-minute download
    └─ Release plan, Safeguards
    │
 PostgreSQL ── app tables, plus the job queue and cache (no Redis needed)
```

The sections that explain *why* are in [`README.md`](README.md#architecture) and [`SOLUTION.md`](SOLUTION.md).

## 5. Settings (environment variables)

Nothing is required for local development. In production set what the table says.

| Variable | Default | What it does |
|---|---|---|
| `PORT` | `3000` | The port Rails listens on |
| `DATABASE_URL` | local `workhappy_*` databases | Production database connection |
| `SECRET_KEY_BASE` / `RAILS_MASTER_KEY` | none | Production secret; set one of them |
| `DEMO_ADMIN_PASSWORD` | `ergocheck-demo-2026` | Password the seeds give the demo admins |
| `ALLOW_DEMO_SEED` | unset | Seeds are skipped in production unless this is `true` |
| `SHOW_OPS_PAGES` | on in dev/test, off in production | Shows the Release plan and Safeguards pages |
| `SOLID_QUEUE_IN_PUMA` | unset | Runs the job worker inside the web process (single-service hosting) |
| `ACTIVE_STORAGE_SERVICE` | `local` | `amazon` stores export files in S3 (needs `AWS_*` variables) |
| `EXPORT_MAX_SECONDS` | `300` | Time budget per export |
| `RAILS_LOG_LEVEL` | `info` (production) | Never use `debug` in production with health data |

The full list with comments is in [`.env.example`](.env.example).

## 6. Everyday tasks

```bash
bin/rails db:seed            # add any missing demo data (never duplicates); prints the accounts
bin/rails db:reset           # wipe the development database and start again from the seeds
bin/rails test               # run the 272 automated tests
bin/ci                       # every check: style, security audits, types, tests
bin/rails console            # a Ruby prompt with the app loaded
```

In `bin/rails console`:

```ruby
# a new admin for an existing company (passwords need at least 12 characters)
Admin.create!(company: Company.find_by!(name: "Northwind Logistics"),
              name: "Sam Ito", email: "sam.ito@northwind.example", password: "a-long-password-1")

# change a password
Admin.find_by!(email: "maya.reyes@northwind.example").update!(password: "another-long-password")
```

## 7. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `Address already in use` / the page is another app | Something else is on port 3000. Run `PORT=4000 bin/dev`. |
| Blank page, or the console says it cannot reach `localhost:3036` | The Vite dev server is not running or its port is taken. Use `bin/dev` (not `bin/rails server` alone), or `VITE_RUBY_PORT=3046 bin/dev`. |
| `PG::ConnectionBad` / could not connect | PostgreSQL is not running (with Homebrew: `brew services start postgresql@<your version>`), or your user cannot create databases. |
| The dashboard looks empty | There may be no data, or a remembered filter (for example *Completed*, *Last 90 days*) is applied. Press **Clear filters**; run `bin/rails db:seed` if the database is empty. |
| Sign-in says the verification did not match | Each code is single-use and expires in five minutes. Type the current image's digits, or switch to the text question. |
| Sign-in says too many attempts | Rate limits protect sign-in: 10 tries per address per 3 minutes and 6 per account per 10 minutes. Wait a few minutes. |
| An export stays *Building* | In production the job worker must be running: set `SOLID_QUEUE_IN_PUMA=1`, or run `bin/jobs` as a separate process. A stuck export is marked stalled after 10 minutes and can be retried. |
| `bundle install` fails on `pg` | Install the PostgreSQL client headers (`brew install libpq`, or `libpq-dev` on Debian/Ubuntu). |
| Release plan / Safeguards give a 404 in production | By design. Set `SHOW_OPS_PAGES=true` to show them. |

## 8. Questions people ask

**Does it use Devise?** No. Sign-in is `has_secure_password` (bcrypt) plus a server-side session table, with the CAPTCHA and rate limits written for this app. There is no sign-up, password reset or e-mail, because admins are provisioned. See the *Why not Devise?* paragraph in the README.

**Why can't I delete an assessment?** Removing health records is a destructive, hard-to-reverse action that the brief does not ask for. Set the status to *Archived* instead.

**Was the status clean-up run on the data?** No. The brief says *plan only*. The mapping, the guarded tasks and the eight-step release and rollback plan are built and tested, and `bin/rails status:backfill:report` shows what the backfill would do without changing anything. New and updated records already use only the five values.

**Can I host it?** Yes. [`RAILWAY_SETUP.md`](RAILWAY_SETUP.md) lists every variable and the steps for Railway (not yet deployed live; see its status note), and a Heroku `Procfile` and `app.json` are included.
