# Changelog

All notable changes, generated from the Conventional Commits history. Versioning follows [SemVer](https://semver.org).

## [Unreleased]

### Features
- **seeds:** add a third tenant and a second admin, and skip production quietly (`a960fdb`)
- **assessments:** add a tenant-safe "New assessment" flow (`ae41044`)
- **deploy:** add `railway.json`, `RAILWAY_SETUP.md` and Railway hosting steps
- **docs:** add `APP_GUIDE.md`; rewrite the README with the architecture, demo logins and hosting steps

### Fixes
- **docs:** say plainly that a new Railway service does not read `railway.json` (Config as Code is unavailable after 2026-08-28) and that the Settings page is the configuration
- **deploy:** run `db:prepare db:seed` when the web process boots, so a platform that skips the pre-deploy step no longer crashes the in-Puma job worker on an empty database; test the real server against an empty database
- **deploy:** give production its own `database.yml` block (it was commented out), stop the boot with a readable message when `DATABASE_URL` is missing, and test it without the variable
- **rate limits:** name each limit so counters don't collide (export previews were using up the hourly export budget), and test every limit against a real cache
- **deploy:** `railway.json` runs one pre-deploy command, as Railway's schema requires, and a test guards it
- **logging:** filter a bare `name` and section `scores`, and stop development query tags from printing values inline (`ae41044` and the fix that follows it)
- **dev:** make bin/dev serve Rails on the documented port (`eaa4d4b`)

## [0.1.0] - 2026-10-10

First release: the three tasks of the take-home assignment, the sign-in / CAPTCHA / cookie extras, an independent security review with its fixes, and the production configuration.

### Features
- **auth:** add an accessible text question as an alternative to the image CAPTCHA (`1325f77`)
- **safeguards:** add the safeguards page with a log line from the real filter (`617b261`)
- **release-plan:** add the status normalization plan page with a live tester (`9e8f4ba`)
- **status:** design the historical backfill as guarded, tested, plan-only code (`bfaf845`)
- **export:** add export dialog, exports page and live progress (`2f08a76`)
- **export:** add company-scoped, redacted CSV export built in the background (`e00fceb`)
- **logging:** filter personal data from logs and prove it from the log itself (`4f49082`)
- **dashboard:** build the assessments page and detail drawer from the design (`fb0711f`)
- **dashboard:** serve a tenant-scoped, paged dashboard with a correct score (`4bb011b`)
- **ui:** add app shell, sign-in page, cookie banner and design tokens (`271cde4`)
- **seeds:** add two demo tenants with the design's dataset and legacy mess (`1096d46`)
- **cookies:** add cookie consent endpoint and opt-in preferences cookie (`7fbee85`)
- **auth:** add self-hosted CAPTCHA to sign-in (`0742613`)
- **auth:** add company-admin sign-in with tenant taken from the session (`eaa026d`)
- **status:** normalise aliases and reject unknown statuses on save (`667591d`)
- **db:** add companies, employees and assessments schema (`486468a`)

### Fixes
- **deploy:** stop the storage guard from breaking every production boot (`c71e9e7`)
- **ui:** meet WCAG contrast, trap focus properly and survive render errors (`a11de55`)
- **status:** make the backfill rollback leave later edits alone (`9080ef9`)
- **security:** close unused upload routes, keep signed links out of logs, gate ops pages (`c4dd75a`)
- **data:** harden redaction, tenant joins, blank statuses and score parsing (`847d7cb`)
- **export:** stop exports whose worker died from sticking in "building" forever (`2c8f4c5`)
- **auth:** make CAPTCHA single-use and sessions revocable by moving state server-side (`0d3c4cf`)
- **logging:** keep signed download links out of the logs (`0486d21`)
- **routes:** limit the 127.0.0.1 redirect to development (`6f7dba6`)

### Performance
- **dashboard:** add measured indexes and a reproducible benchmark (`677ce9d`)

### Build and dependencies
- **npm:** sync the lockfile with the engines field (`222eb8f`)
- **deploy:** configure a single-database, Heroku-like production setup (`ae56f36`)
- **deps:** drop unused image_processing and disable variant processing (`1841d78`)
- **npm:** pin an explicit package name (`5575e26`)

### CI
- stop replanting seeds into the test database (`30b39bb`)

### Tests
- build the vite bundle once before parallel workers fork (`45a28bf`)

### Style
- **ui:** hide the scrollbar under the mobile navigation (`657d336`)

### Documentation
- record the independent review and finish the project checklist (`487a94a`)
- **audit:** add v1 production audit checklist (`ef63c58`)
- **audit:** archive pre-audit documentation to docs/v1_docs (`cb5d2cd`)
- add .env.example listing every variable the code reads (`a5c6bb3`)
- add README, SOLUTION and the release runbook (`d981e35`)

### Chores
- **release:** prepare v0.1.0 (`c748751`)
- scaffold rails 8.1 app with inertia, react, typescript and vite (`b4a107d`)
