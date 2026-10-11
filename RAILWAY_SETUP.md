# Hosting ErgoCheck on Railway: variables, setup, and running it

Everything you need to put the app on [Railway](https://railway.com): what to create, **which environment variables to set and where each value comes from**,
how to check it works, and how to run things afterwards. The short version lives in the [README](README.md#hosting-on-railway).

> **Status, stated plainly.** The hosting configuration ([`railway.json`](railway.json), the [`Dockerfile`](Dockerfile), the seeds) is written, and the same steps were run **locally in
> production mode** and passed (release build, `db:prepare db:seed`, `bin/rails server -b ::`, the job worker inside Puma, an export built and downloaded, the health check on IPv4 and IPv6).
> I have **not deployed it to a live Railway project myself**, because I had no Docker or Railway account to do it with. The owner's first deploy found a real bug (the `production:` block in `config/database.yml` was commented out, so production only worked when `DATABASE_URL` was set; fixed, and the app now stops with a clear message instead), which is a good reason to treat the rest with the same caution. Railway's behaviour below comes from its documentation. Read the deploy's logs and
> trust them over this file where they disagree.

**Contents:** [1 What you will have](#1-what-you-will-have) · [2 Before you start](#2-before-you-start) · [3 The environment variables](#3-the-environment-variables) ·
[4 Set it up in the dashboard](#4-set-it-up-in-the-dashboard) · [5 Or use the CLI](#5-or-use-the-cli) · [6 Check that it works](#6-check-that-it-works) ·
[7 Run things on the server](#7-run-things-on-the-server) · [8 Update, roll back, back up](#8-update-roll-back-back-up) · [9 Optional: a separate worker](#9-optional-a-separate-worker-service) ·
[10 Before you share the URL](#10-before-you-share-the-url) · [11 Troubleshooting](#11-troubleshooting)

---

## 1. What you will have

```
 GitHub repository ─▶ Railway project
                       ├─ "app" service   built from the Dockerfile, configured on its Settings page
                       │     pre-deploy:  bin/rails db:prepare db:seed
                       │     start:       bin/rails server -b ::      (Puma + the job worker inside it)
                       │     health:      GET /up  → 200
                       │     public URL:  https://<something>.up.railway.app
                       ├─ "Postgres" service   one database: app tables + job queue + cache
                       └─ Volume on the app service, mounted at /rails/storage   (export files)   [or S3 instead]
```

Two services, one volume. No Redis, no separate worker, no separate API.

## 2. Before you start

- [ ] A Railway account, and the repository **pushed to GitHub** (Railway deploys from it).
- [ ] You can generate a secret: `bin/rails secret` in the project folder (or `openssl rand -hex 64`). **Keep the value in a password manager.**
- [ ] You have decided on a **demo password** for the sample admins (at least 12 characters; longer is better).
- [ ] Decided where exports are stored: a **Volume** (simplest) or **S3** (section 3.4).

## 3. The environment variables

Set them on the **app service** → **Variables** tab. The **Raw Editor** lets you paste many at once.

### 3.1 Copy-paste block (Raw Editor)

Replace the two `<…>` values, keep everything else as written. `Postgres` must match the **exact name** of your database service in the project.

```dotenv
DATABASE_URL=${{Postgres.DATABASE_URL}}
SECRET_KEY_BASE=<paste the output of: bin/rails secret>
SOLID_QUEUE_IN_PUMA=1
ALLOW_DEMO_SEED=true
DEMO_ADMIN_PASSWORD=<a long password you choose>
SHOW_OPS_PAGES=true
RAILWAY_RUN_UID=0
```

`${{Postgres.DATABASE_URL}}` is Railway's *reference variable* syntax: Railway fills in the database service's private connection string for you, and keeps it up to date.
`RAILWAY_RUN_UID=0` is only needed because you attach a Volume (3.4); leave it out if you use S3.

### 3.2 What each variable does

| Variable | Value | Required? | What it does, and what happens without it |
|---|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | **Yes** | How the app finds Postgres. The same single database holds the app tables, the job queue and the cache. **Without it the app stops at boot** with ``DATABASE_URL is not set, so the app has no database to connect to`` (older builds showed the cryptic ``The `production` database is not configured for the `production` environment``). |
| `SECRET_KEY_BASE` | 128 hex characters from `bin/rails secret` | **Yes** | Signs and encrypts cookies and signed links, and seeds the one-way `emp_…` employee references. Without it the app refuses to start. **Changing it later signs everyone out and changes every `emp_…` reference in future exports.** |
| `SOLID_QUEUE_IN_PUMA` | `1` | **Yes** (single-service setup) | Starts the job worker inside the web process. **Without it the app works but exports stay "Building" forever**, because nothing runs the job. |
| `PORT` | *(do not set)* | No | Railway provides it (8080 in the logs of a real deploy) and Puma listens on it (`Listening on http://[::]:8080`). Only set it if you want a fixed port; then make the domain's port match. |
| `ALLOW_DEMO_SEED` | `true` | For a demo | Lets `db:seed` create the demo companies and admins. In production it is otherwise skipped (quietly), so a real deployment never gets demo accounts by accident. |
| `DEMO_ADMIN_PASSWORD` | your choice | **Yes, if `ALLOW_DEMO_SEED=true`** | The password of all four demo admins. If you forget it, the **documented public default** from the README is used, which anyone can read. Always set it. |
| `SHOW_OPS_PAGES` | `true` | Optional | Shows the internal *Release plan* and *Safeguards* pages. They return 404 in production by default. Good for a demo or a reviewer; leave it off for real use. |
| `RAILWAY_RUN_UID` | `0` | Only with a Volume | The image runs as a non-root user, which cannot write to a freshly mounted volume. Railway's documented fix is to run as root with this variable. |

`RAILS_ENV=production` is **already set inside the Dockerfile**; you do not need to add it.

### 3.3 Optional tuning

| Variable | Default | When to change it |
|---|---|---|
| `EXPORT_MAX_SECONDS` | `300` | Seconds an export may run before it fails with "try a narrower range". |
| `RAILS_LOG_LEVEL` | `info` | **Never `debug` in production**: it logs SQL and parameters for health data. |
| `RAILS_MAX_THREADS` | `3` | Puma threads per process (also sizes the database connection pool). |
| `WEB_CONCURRENCY` | `1` | Number of Puma worker processes. Leave unset unless you need 2 or more. |
| `JOB_CONCURRENCY` | `1` | Number of job worker processes. |
| `SKIP_DB_PREPARE` | unset | The web process runs `db:prepare db:seed` itself at boot (see below). Set `1` only if schema changes must happen exclusively in a separate release step. |

### 3.4 Where export files are stored (choose one)

An export is a CSV file written through Active Storage. A Railway container's own disk is **wiped on every deploy**, so give it somewhere durable:

**Option A: a Volume (simplest).** Create it with the Command Palette (`⌘K`) or by right-clicking the project canvas; Railway asks which service to attach it to (the app service). Then set the volume's **mount path to `/rails/storage`** on that service, and keep `RAILWAY_RUN_UID=0` in the variables.
Per Railway's documentation: a service can have **one** volume, services with a volume cannot use replicas, and **redeploying a service with a volume causes a short downtime**. The pre-deploy command does not see the volume, which is fine because it only touches the database.

**Option B: S3-compatible storage (more robust, needed if you add a separate worker).** Create a **private** bucket and a key that can only use that bucket, then set:

| Variable | Value |
|---|---|
| `ACTIVE_STORAGE_SERVICE` | `amazon` |
| `AWS_S3_BUCKET` | your bucket name |
| `AWS_ACCESS_KEY_ID` | the key's id |
| `AWS_SECRET_ACCESS_KEY` | the key's secret |
| `AWS_REGION` | the bucket's region (default `eu-west-1`) |

I could not test S3 here (no credentials), so try one export right after setting it.

### 3.5 Set by Railway: do not set these yourself

`RAILWAY_PUBLIC_DOMAIN`, `RAILWAY_ENVIRONMENT_NAME`, `RAILWAY_SERVICE_NAME`, `RAILWAY_GIT_COMMIT_SHA` and the other `RAILWAY_*` values are injected automatically. The app does not read them.
(`RAILWAY_RUN_UID`, `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` and a few others are *settings you may choose to add*, as above.)

### 3.6 Values to keep out of the repository

Never commit any of the values above. They live in Railway's Variables tab (and in your password manager). `config/master.key` is git-ignored and **not needed**: the app runs from `SECRET_KEY_BASE`.

---

## 4. Set it up in the dashboard

1. **Create the project.** Railway → **New Project → Deploy from GitHub repo** → choose the repository. Railway sees the `Dockerfile` and builds it (the Builder box may say Railpack; with a Dockerfile in the repository the Dockerfile is used, as the build log shows). **`railway.json` is not read for a new service** (see the next step), so the settings come from you.
   *The first deploy will stop with a missing `secret_key_base` message. That is expected; the variables come next.*
2. **Add the database.** In the project canvas: **Create / New → Database → Add PostgreSQL**. Note the service's name (normally `Postgres`).
3. **Add the variables.** Open the **app** service → **Variables** → **Raw Editor**, paste the block from section 3.1 (with your two values), and save.
4. **Add storage.** A Volume mounted at `/rails/storage` (Option A: ⌘K or right-click the canvas, attach it to the app service, set the mount path) or the S3 variables (Option B).
5. **Set the service's Settings yourself.** Railway's own Settings page says: "Config as Code is deprecated … Starting 2026-08-28, services that have never used Config as Code cannot opt in." For a service created after that date, `railway.json` is **not read**, and the values on the Settings page are the only configuration. Open the app service → **Settings** and set these four (they are the values `railway.json` records):
   - **Builder:** Dockerfile
   - **Pre-deploy command:** `bin/rails db:prepare db:seed` (the recommended place to create the tables and the demo data. The web process also runs the same two tasks when it boots, so a missing pre-deploy command no longer leaves you with an empty database, but a failed pre-deploy is a clearer signal than a failed boot)
   - **Custom start command:** `bin/rails server -b ::` (or empty, so the image's own command runs). If you see `bundle exec puma -C config/puma.rb` here, that is the `Procfile` (the Heroku path); it neither prepares the database nor binds IPv6, so replace it.
   - **Healthcheck path:** `/up`
   Then check **Variables**: `DATABASE_URL` must show a real `postgres://…` value (open it to see), not an empty value or an unresolved `${{…}}`.
6. **Deploy.** Saving variables usually triggers a new deployment; if not, use **Deploy** (or **Redeploy** on the latest deployment).
7. **Watch the logs.** Open the deployment → **Build logs**, then **Deploy logs**. A healthy run shows, in order:
   - the Docker build finishing (gems installed, the Vite bundle built, `assets:precompile`);
   - the pre-deploy step: the database being prepared and the seed lines, e.g. `Northwind Logistics: seeded 64 assessments for 64 employees` (first deploy) or `…already present, skipping` (later ones);
   - Puma starting (`Listening on http://[::]:3000`) and the job worker starting (`SolidQueue-… Started Supervisor`, `Started Worker`, `Started Scheduler`);
   - the health check passing and the deployment turning **Active**.
8. **Give it a public address.** App service → **Settings → Networking → Generate Domain**. Railway detects the listening port; if it shows a wrong one, edit it to the number in the log line `Listening on http://[::]:NNNN` (pencil icon next to the domain).
9. Open the URL and continue with section 6.

## 5. Or use the CLI

Install: `brew install railway` (or `npm i -g @railway/cli`). Then, from the project folder:

```bash
railway login                       # opens a browser
railway init                        # a new project (or `railway link` to use an existing one)
railway add --database postgres     # adds the PostgreSQL service
railway variable set SECRET_KEY_BASE="$(bin/rails secret)"
railway variable set SOLID_QUEUE_IN_PUMA=1
railway variable set ALLOW_DEMO_SEED=true
railway variable set SHOW_OPS_PAGES=true
railway variable set RAILWAY_RUN_UID=0
railway variable set DEMO_ADMIN_PASSWORD='<a long password you choose>'
railway variable set DATABASE_URL='${{Postgres.DATABASE_URL}}'      # single quotes: the reference is Railway's, not your shell's
railway up                          # builds and deploys the current folder
railway domain                      # generates the public URL
railway logs                        # deploy logs (add --build for build logs)
```

If a command asks which service you mean, choose the app service (or pass `--service <name>`). The Volume is easiest to add in the dashboard. Check `railway --help` if a command's wording differs in your CLI version.

## 6. Check that it works

| Check | What you should see |
|---|---|
| Open `https://<your-domain>/up` | a small page / HTTP 200 |
| Open the domain | the **Sign in** page and a cookie banner |
| Sign in as `maya.reyes@northwind.example` with your `DEMO_ADMIN_PASSWORD` | the dashboard with **64** assessments (Northwind) |
| Sign out, sign in as `jonas.weber@harborpine.example` | a different, smaller dataset (**24**); Maya's data is not visible |
| Press **Export CSV → Request export** | progress, then **Export ready**; the downloaded file has six columns and no names or e-mail addresses |
| Press **New assessment** | you can add one; it appears in the list |
| `…/release_plan` | the plan page (only if `SHOW_OPS_PAGES=true`; otherwise 404, which is correct) |

If the export stays at *Building*, `SOLID_QUEUE_IN_PUMA` is missing. If it fails right away, check the storage option (3.4).

## 7. Run things on the server

Open a shell inside the running service, then use the normal commands:

```bash
railway ssh                                  # a shell in the deployed app service
bin/rails console                            # a Ruby prompt with the app loaded
bin/rails status:backfill:report             # read-only audit of status values (safe)
bin/rails db:seed                            # re-run the idempotent seeds
```

In `bin/rails console`, to provision a real admin or change a password (passwords need at least 12 characters):

```ruby
Admin.create!(company: Company.find_by!(name: "Northwind Logistics"),
              name: "Sam Ito", email: "sam.ito@example.com", password: "a-long-password-1")
Admin.find_by!(email: "maya.reyes@northwind.example").update!(password: "another-long-password")
```

`railway run <command>` runs a command **on your own computer** with the service's variables; the database's private address is not reachable from outside Railway, so prefer `railway ssh` for anything that touches the database.

## 8. Update, roll back, back up

- **Deploy a change:** push to the branch the service watches; Railway builds, runs the pre-deploy step, starts the new version and waits for `/up`. **If the pre-deploy command or the health check fails, the new version is not activated and the previous one keeps serving.**
- **Roll back:** the service's **Deployments** list → the three-dot menu on an earlier successful deployment → **Rollback**. It restores that deployment's image **and its variables**. (Old deployments past your plan's retention cannot be rolled back.)
- **Logs:** dashboard → deployment → logs, or `railway logs`.
- **Back up the database** (do this before the status release steps in [`db/release_plan/RUNBOOK.md`](db/release_plan/RUNBOOK.md)):
  1. On the **Postgres** service: **Settings → Networking → Public Access** (this creates the `DATABASE_PUBLIC_URL` variable; Railway bills network egress for it, so switch it off afterwards).
  2. `pg_dump "<DATABASE_PUBLIC_URL value>" -Fc -f ergocheck-$(date +%F).dump`
  3. Prove it restores: `createdb scratch && pg_restore -d scratch --no-owner ergocheck-*.dump && psql scratch -c "select count(*) from assessments"`
  Railway also has a native Backups feature; check its documentation for plan eligibility before relying on it.

## 9. Optional: a separate worker service

The single-service setup runs jobs inside Puma. That is simplest, but a heavy export load can slow web requests. To separate them:

1. Set the web service's **Custom Start Command** to `bin/rails server -b ::` in its **Settings** (if you also use a legacy `railway.json`, delete its `startCommand` line: it would apply to every service of the repository, including the worker).
2. On the web service, **remove** `SOLID_QUEUE_IN_PUMA`.
3. Add a second service from the same repository. Give it the same variables (`DATABASE_URL`, `SECRET_KEY_BASE` and the storage ones) and the start command **`bin/jobs`**.
4. **Use S3 (Option B).** A volume belongs to one service, so a file built by the worker would not be visible to the web service.

## 10. Before you share the URL

- [ ] `DEMO_ADMIN_PASSWORD` is set to something only you know (the default is public, in the README).
- [ ] You are comfortable with the demo data being fictional and visible to anyone who gets the password. For real use, remove `ALLOW_DEMO_SEED` and create real admins (section 7).
- [ ] `RAILS_LOG_LEVEL` is not `debug`.
- [ ] `SHOW_OPS_PAGES`: on only if you want reviewers to see the internal pages.
- [ ] The CAPTCHA and rate limits are on by default; sign-in is limited per address and per account.
- [ ] `SECRET_KEY_BASE` is stored somewhere safe, and was never pasted into the repository, an issue or a chat.

## 11. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Logs: ``The `production` database is not configured for the `production` environment`` (or, on newer builds, ``DATABASE_URL is not set``) | The app service has **no `DATABASE_URL`**. Open the **app** service (not the Postgres service) → **Variables** and add `DATABASE_URL` = `${{Postgres.DATABASE_URL}}`. The name before the dot must match your PostgreSQL service's name exactly (check it in the project canvas), both must be in the same environment, and the value must show as resolved. Redeploy. (Older builds of this repo also had a bug: the `production:` header in `config/database.yml` was commented out, so production relied on that variable alone. Fixed.) |
| Logs: ``relation "solid_queue_recurring_tasks" does not exist`` then ``Detected Solid Queue has gone away, stopping Puma`` (or pages failing with ``relation "admins" does not exist``) | The database is **empty**: nothing created the tables, because the pre-deploy command did not run and the start command (`bundle exec puma …`, the Procfile) bypasses the image's entrypoint. Builds from commit `config/puma.rb` onward create the tables themselves at boot, so **pull the latest code and redeploy**. On an older build, set the pre-deploy command in **Settings** (`bin/rails db:prepare db:seed`) and redeploy. |
| Logs show `bundle exec puma -C config/puma.rb` as the command | That is the `Procfile` (the Heroku path). Set the **Custom start command** to `bin/rails server -b ::` (or clear it). |
| Deploy fails: `Missing secret_key_base` | `SECRET_KEY_BASE` is not set (or set on the wrong service). Add it and redeploy. |
| Pre-deploy fails: could not connect / `connection refused` | `DATABASE_URL` does not reference the database service. The name inside `${{…}}` must match the Postgres service's name exactly. |
| Health check fails (deploy never goes Active) | Open the deploy logs. Common causes: the app crashed on boot (a missing variable), or the database is not reachable. `/up` itself is unauthenticated and not host-filtered. |
| The URL shows "Application failed to respond" / 502 | The domain points at a port the app is not listening on. Read the deploy log line `Listening on http://[::]:NNNN` and make the domain's port (Settings → Networking, pencil icon) match that number. |
| Sign-in loops or cookies are lost | Use the **https** URL. The app forces secure cookies in production. |
| Export stays *Building* | `SOLID_QUEUE_IN_PUMA=1` is missing (or the worker service is not running). A stuck export is marked stalled after 10 minutes and can be retried. |
| Export fails immediately, or the file is gone after a deploy | No durable storage. Add the Volume (3.4 A) or S3 (3.4 B). Exports are only kept for 24 hours anyway. |
| `Permission denied` writing to `/rails/storage` | Add `RAILWAY_RUN_UID=0` (the image runs as a non-root user). |
| Demo companies are missing | `ALLOW_DEMO_SEED` is not `true`, or the pre-deploy step did not run. Check the deploy logs for `Skipping demo data in production`. |
| I forgot the demo password | `railway ssh`, then `bin/rails console` and update the admin (section 7). |
| `/release_plan` or `/safeguards` gives 404 | By design in production. Set `SHOW_OPS_PAGES=true`. |
| `railway.json` seems to have no effect | Correct: Config as Code is deprecated and unavailable to services created after 2026-08-28 (the Settings page says so). Set the values in **Settings**: Builder = Dockerfile (optional: the Dockerfile is used anyway) · **Pre-deploy Command** = `bin/rails db:prepare db:seed` · **Custom Start Command** = `bin/rails server -b ::` · **Healthcheck Path** = `/up`. |

## 12. What this guide cannot promise

- A live Railway deployment has not been run by me; steps and UI names come from Railway's documentation and may have moved.
- The Docker build was not run in my environment (the same steps were run directly, in production mode).
- S3 storage and a separate worker service are untested.
- Prices and plan limits are not covered here: check Railway's pricing for one app service, one Postgres service and one volume.
