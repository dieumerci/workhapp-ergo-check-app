# Production Audit Checklist — v1

| | |
|---|---|
| Audit cycle | v1 (first cycle) |
| Date | 2026-10-10 |
| Commit audited | `c71e9e7` (fix(deploy): production boot guard). The gate was re-run on this code after the last fix; commits after it are documentation and release prep only |
| Previous docs archived to | `docs/v1_docs/` (empty: `docs/` held no files; project docs live at the repo root, see Documentation) |
| **Verdict** | **No open P0–P2 findings.** 0 blocker · 0 high · 0 medium · **8 low (P3) awaiting your sign-off.** Not declared PRODUCTION READY until those are signed off or fixed. |

## Project profile

| | |
|---|---|
| Platforms / app type | Web only: Rails 8.1 + Inertia.js 3 + React 19 + TypeScript + Vite 8 + Tailwind 4 |
| Backend / auth | PostgreSQL (single database, Solid Queue + Solid Cache tables inside it); custom company-admin sign-in with server-side sessions, CAPTCHA and consent-gated cookies |
| Monetization | expected: none · detected: none (no `stripe`, `purchases_*`, `pay`) · status: **free — assumed**, because the brief contains no paid feature. *Please confirm.* |
| i18n locales | en only (single-locale internal tool; not required by the brief) |
| CI/CD | GitHub Actions (`ci.yml`: Ruby and JS scans, lint, tests, system tests) and `bin/ci` |
| Skills & tools used | checklist-orchestrator, task-delivery, conventional-commits, zero-warnings, production-readiness-audit; built-in browser pane (every screen, mobile width, keyboard behaviour); an independent read-only reviewer subagent for correctness/security (used in place of the `code-review` and `security-review` skills) |

## Gate evidence

| Check | Result | Evidence |
|---|---|---|
| Checklist | 46/47 items ticked and spot-checked (CHECKLIST.md); the one open item, 10.4 (the Loom video), is yours to record | spot-checks: tenancy, redaction, export, status, release plan, safeguards, cookies, CAPTCHA each exercised in the browser and in tests; no false ticks found |
| Tests (run 1 / run 2) | 231 passed · 0 failed · 0 skipped / 231 passed · 0 failed · 0 skipped | `bin/rails test` run twice back to back; no `skip`/`xit`/`.only`/commented tests (grep) |
| Coverage (critical modules) | not measured (no coverage gem installed) | see *Not verifiable*; the feature → test map below is built from the code |
| Static checks | clean | `bin/rubocop` (0 offenses), `bin/brakeman` (0 warnings, 1 documented false positive), `bin/bundler-audit` (none), `npm audit` (0), `npm run check` (0 TypeScript errors) |
| Release build | ok | `RAILS_ENV=production bin/vite build` (no warnings); production mode booted against a scratch DB; fresh `git clone` → install from lockfiles → `db:setup` → tests on a cold cache → `bin/ci` → build → production boot; then a full production-mode run on the final code (scratch DB, separate worker process): text-question sign-in, export built by the worker, signed download, copied-cookie replay rejected after sign-out |
| Whole pipeline | ok | `bin/ci` (10 s) |
| Monetization gate | N/A | declared free (assumption above) |

## Delta vs previous cycle

First cycle, so there is nothing to compare. Counts for this cycle: **23 findings raised: 22 fixed, 1 withdrawn (by design).** Separately, 8 low-severity items await your sign-off (they are decisions, not findings).

| Fixed | Regressed | New | Carried over |
|---|---|---|---|
| 22 | 0 | 22 | 0 |

Open P0–P2 trend: v1: 11 raised → 0 open.

## Summary

The application meets all three tasks and the two extras, and the full check pipeline is clean. The first audit pass (mine) found accessibility contrast and a handful of hygiene items; an **independent reviewer, given only the code and the brief,** then found two genuinely serious defects I had missed: a CAPTCHA that could be replayed because its state lived in the client's cookie, and exports that could stick in "building" forever and lock a company out. Every finding was reproduced, fixed with a test that fails without the fix (several were mutation-checked), and merged. The last one is mine: re-running the gate on a fresh clone of the final commit showed that my own hardening commit had **broken every production boot** (an initializer referenced an autoloaded constant), which dev and test never exercise; it is fixed and now guarded by a test that boots production mode in a subprocess. What remains is a short list of low-severity items that are product decisions, not defects; they need your sign-off.

## Needs fixing

*Everything below is fixed in this cycle; the evidence is the commit and the test that fails without the fix.*

### P1 — High

- [x] **AUD-v1-001** · Security · `app/models/captcha.rb`, `app/controllers/concerns/authentication.rb` · confirmed
  **Evidence:** the CAPTCHA digest lived only in the cookie-store session; replaying the original cookie passed the same challenge 10 of 10 times; sign-out could not revoke a copied cookie.
  **Problem:** one solved challenge gave unlimited password guesses for 5 minutes (limited only by per-IP rate limit), and a stolen cookie survived sign-out.
  **Fix:** server-side `captcha_challenges` (verify = delete, the delete is the gate) and `admin_sessions` (revocable, server-enforced idle expiry); per-account sign-in throttle; background polls no longer count as activity.
  **Verify by:** `captcha_test` "a captured cookie cannot replay…", "ten replays…"; `authentication_test` "signing out revokes the session…", "background polling does not count as activity". Commit `0d3c4cf`. *(A first version used `DELETE … RETURNING` through `select_one`, which the query cache answered without executing; the replay tests caught it.)*

- [x] **AUD-v1-002** · Reliability · `app/jobs/assessment_export_job.rb`, `app/models/assessment_export.rb` · confirmed
  **Evidence:** three simulated crashed workers left three exports `processing`, no Retry button, the fourth export refused with "3 in progress".
  **Problem:** a killed worker locks a company out of exports and the page polls forever.
  **Fix:** heartbeat (`updated_at` per batch), stalled state shown as failed + Retry at once, `claim!` takes over a dead claim, cap counts only live exports, `ReapStuckExportsJob` every 5 minutes.
  **Verify by:** `exports_test` "an export nobody is working on shows as failed…", "a re-run after a crash takes over…", "a live claim is left alone", "the reaper…", "dead exports do not count towards the cap…". Commit `2c8f4c5`.

- [x] **AUD-v1-023** · Deployment · `config/initializers/active_storage_guard.rb` · confirmed
  **Evidence:** `RAILS_ENV=production bin/rails runner …` raised `uninitialized constant ActiveStorageGuard` from a fresh clone of the final commit.
  **Problem:** the guard added in the security-hardening unit referenced a `lib/` constant while initializers were still running, so **no production process could boot**. Dev and test skip that branch, so all 228 tests were green, and the earlier production-mode run predated the guard.
  **Fix:** run the guard in `after_initialize`; add `test/production_boot_test.rb`, which boots the real production environment in a subprocess (normal boot, refusal on an ephemeral disk without object storage, accepted with S3 configured).
  **Verify by:** `production_boot_test` (3 tests; all 3 fail with the original initializer, mutation-checked). Commit `c71e9e7`. *Found by the "re-run the gate on the current commit" rule, not by any earlier check.*

### P2 — Medium

- [x] **AUD-v1-003** · Security · `config/application.rb` · confirmed — Active Storage's unauthenticated direct-upload endpoints were routed. **Fix:** `draw_routes = false`, only the signed download route drawn. **Verify by:** `security_hardening_test` (5 endpoints → 404; route table). `c4dd75a`
- [x] **AUD-v1-004** · Data · `app/models/status_backfill.rb` · confirmed — rollback overwrote statuses edited after the backfill. **Fix:** restore only rows still holding the backfilled value; report the rest. **Verify by:** `status_backfill_test` "rollback does not undo an edit made after the backfill". `9080ef9`
- [x] **AUD-v1-005** · Correctness · `app/models/assessment.rb` · confirmed — a PATCH with a blank/missing status reset an archived assessment to pending and hid its score. **Fix:** explicit blanking of an existing status is rejected. **Verify by:** `assessment_test`, `assessments_dashboard_test` "an update that forgets the status…". `847d7cb`
- [x] **AUD-v1-006** · Performance/Abuse · `app/controllers/exports_controller.rb` · confirmed — the heavy `preview` endpoint was unthrottled. **Fix:** 60/minute, JSON the dialog already displays. Verified manually (60×200 then 429s) because the test cache is null. `2c8f4c5`
- [x] **AUD-v1-007** · Security/Logging · `config/initializers/` · confirmed — at `RAILS_LOG_LEVEL=debug` the full signed download URL was logged by Active Storage, and the disk-service request path carried the token. **Fix:** log subscriber detached, request lines silenced. **Verify by:** `security_hardening_test` "neither the signed link nor Active Storage's debug line reaches the log" (fails when either protection is removed). `c4dd75a`
- [x] **AUD-v1-008** · Accessibility · `app/javascript/entrypoints/application.css` · confirmed — the design's `subtle` colour was 3.16:1 on white (2.84:1 on the page) for real information. **Fix:** darkened to 5.0:1 / 4.5:1; all other pairs already passed. **Verify by:** contrast computation in this audit. `a11de55`
- [x] **AUD-v1-009** · Accessibility · `app/javascript/components/Dialog.tsx` · confirmed — Shift+Tab escaped the modal, the page behind stayed reachable, Escape closed stacked dialogs. **Fix:** portal + `inert` app root, topmost-only key handling, focus pulled inside. **Verify by:** browser: `#app.inert`, Shift+Tab → last control, 8 Tabs cycle, Escape restores focus. `a11de55`
- [x] **AUD-v1-010** · Accessibility · `app/javascript/pages/sessions/new.tsx` · confirmed — the image CAPTCHA had no non-visual alternative: blind admins could not sign in (WCAG 1.1.1 / 3.3.8). **Fix:** screen-reader-readable text question, same server-side single-use mechanism, stricter throttle. **Verify by:** `captcha_test` text-question tests; signed in through it in the browser. `1325f77`

### P3 — Low (fixed)

- [x] **AUD-v1-011** · `employee_ref` was 32 bits (collides at ~50,000 employees) → 48 bits. `847d7cb`
- [x] **AUD-v1-012** · dashboard join did not pin the employee to the assessment's company → tenant-pinned LEFT JOIN, shows "Unknown employee". `847d7cb`
- [x] **AUD-v1-013** · `localStorage` survived consent withdrawal → cleared on withdrawal. `a11de55`
- [x] **AUD-v1-014** · production defaulted to a local disk on ephemeral platforms → boot refused when `DYNO` is set without object storage; `ActiveStorageGuard` tested. `c4dd75a`
- [x] **AUD-v1-015** · internal Release plan / Safeguards pages visible to every tenant in production → 404 unless `SHOW_OPS_PAGES`. `c4dd75a`
- [x] **AUD-v1-016** · the export loaded employee names it never wrote (comment claimed otherwise) → dedicated `export_relation`; a test asserts the batch SQL never mentions names, e-mails or free text. `847d7cb`
- [x] **AUD-v1-017** · `"0x1A"` and `"1e2"` were scored as 26 and 100 → decimal digits only. `847d7cb`
- [x] **AUD-v1-018** · no React error boundary: a render error blanked the app → boundary logging only the error name. Verified in the browser. `a11de55`
- [x] **AUD-v1-019** · no `.env.example` for 20+ variables → added, and `.gitignore` tracks it. `a5c6bb3`
- [x] **AUD-v1-020** · `bin/ci` replanted seeds into the test DB, breaking the next run → step removed (seeds covered by `seeds_test`). `30b39bb`
- [x] **AUD-v1-021** · lockfile named after the checkout directory / missing `engines` → pinned name, synced. `5575e26`, `222eb8f`

### Withdrawn

- **AUD-v1-022** (reviewer: "a computable score is hidden by status" for legacy blank-status rows). **By design:** the design says Pending/In-progress show "Not scored yet", and legacy blank statuses normalise to Pending. Those exact rows are what `status:backfill:report` lists ("blank AND already has answers") for a human to review. Showing a score regardless of status would contradict the design. Documented in SOLUTION §6.2.

## Fix plan (delivery units, all delivered)

| # | Unit (root cause) | Items | Commit subject |
|---|---|---|---|
| 1 | CAPTCHA and session state held by the client | 001 | `fix(auth): make CAPTCHA single-use and sessions revocable by moving state server-side` |
| 2 | Exports whose worker died | 002, 006 | `fix(export): stop exports whose worker died from sticking in "building" forever` |
| 3 | Data correctness and redaction | 005, 011, 012, 016, 017 | `fix(data): harden redaction, tenant joins, blank statuses and score parsing` |
| 4 | Unused upload routes, logs, deployment guards | 003, 007, 014, 015 | `fix(security): close unused upload routes, keep signed links out of logs, gate ops pages` |
| 5 | Backfill rollback | 004 | `fix(status): make the backfill rollback leave later edits alone` |
| 6 | Accessibility and resilience | 008, 009, 013, 018 | `fix(ui): meet WCAG contrast, trap focus properly and survive render errors` |
| 7 | CAPTCHA accessibility | 010 | `feat(auth): add an accessible text question as an alternative to the image CAPTCHA` |
| 8 | Production boot broken by the storage guard | 023 | `fix(deploy): stop the storage guard from breaking every production boot` |
| 9 | Hygiene | 019, 020, 021 | `docs: add .env.example…`, `ci: stop replanting seeds…`, `build(npm): …` |

## Monetization

| Check | Status | Evidence |
|---|---|---|
| Provider fits platform | N/A | no paid feature in the brief; declared free (assumed) |
| Everything else in the matrix | N/A | no `stripe`, `purchases_*`, `pay`, no webhooks, no entitlements |

## Verified done

- [x] **1 Clean setup** — fresh clone → `bundle install` + `npm ci` → `db:setup` → 231 tests (cold Vite cache) → release build → production boot, all in a scratch directory and scratch databases; tool versions pinned (`.ruby-version`, `engines.node`); README steps complete (`bin/setup` includes `npm install`).
- [x] **2 Configuration & secrets** — no secrets in history (`sk_live`, `service_role`, `AKIA`, `BEGIN … PRIVATE KEY`, `password=`: 0 added lines); no key files tracked; `.env.example` lists every variable (`grep ENV[` inventory); debug off in production (`log_level info`); CSP + HSTS + secure/HttpOnly/SameSite cookies verified on a real production-mode response.
- [x] **3 Architecture & code quality** — no `TODO|FIXME|HACK|XXX`; RuboCop clean with no blanket disables; Brakeman ignore carries a written justification. Dead-dependency check: `csv`, `aws-sdk-s3`, `chunky_png`, `bcrypt`, `minitest-mock` are used; `propshaft` has no helper usages **but is kept deliberately**, because vite_ruby only hooks `assets:precompile` if that task exists, so removing it would silently stop the Dockerfile and Heroku buildpack from building the front end. `kamal`/`thruster` are scaffold deploy tooling referenced by the Dockerfile and `config/deploy.yml`.
- [x] **4 Every feature end to end** — walked in the browser: sign-in (image, text alternative, wrong code), cookie banner/dialog, dashboard filters, presets, paging, drawer, status change, export dialog → job → download (file inspected), failed state + Retry, Exports page, Release plan tester, Safeguards, mobile width, production mode. States covered: loading skeleton, empty, error, failed, expired, stalled.
- [x] **5 Data layer** — migrations apply from zero (scratch DB, production env); FKs, unique indexes (`companies.name`, `admins.email`, `admin_sessions.token_digest`), indexes on every filtered/ordered column (EXPLAIN-verified); backups and rollback in the runbook; PII inventory below.
- [x] **6 Security** — tenant isolation (every lookup through `Current.company`, mutation-checked); IDOR (other tenant's export/assessment → 404); CSRF (token accepted, absence → 422, verified in production mode); session fixation/reset; server-side revocation; rate limits (IP, account, preview, text question); CAPTCHA single-use; open redirects (`redirect_back_or_to` only); CSV injection guard; XSS (no `dangerouslySetInnerHTML`, React escaping); dependency audits clean; headers (CSP, HSTS, `frame-ancestors none`, referrer/nosniff defaults).
- [x] **7 Tests** — behaviour-asserting, deterministic, green twice, mutation checks on tenancy, log filters, revocation, and the signed-link log protection; run in CI on every PR.
- [x] **8 UI/UX & accessibility** — compared with the design's screenshots; all text pairs ≥ 4.5:1 after AUD-008; keyboard: rows and dialogs operable, focus visible, trap and restore verified; labels and roles on every control; `prefers-reduced-motion` honoured; loading/empty/error states designed; phone width usable.
- [x] **10 Performance** — measured: 94.5 s / 300,001 queries → 23 ms / 2 queries at 300k rows; pagination on every list; no N+1; bundle 346 kB (108 kB gzip) React chunk + 14 kB app code.
- [x] **11 Reliability & observability** — error boundary; `/up` health check excluded from SSL redirect; request-id log tags; jobs fail to a generic code, never raw messages; stuck-export reaper; time budget; idempotent claim.
- [x] **13 Build, CI/CD & release** — `bin/ci` and the GitHub workflow run lint, types, audits, Brakeman, tests; release build reproducible; `CHANGELOG.md` generated from Conventional Commits; migration idempotent and reversible both ways; **documented rollback** (`db/release_plan/RUNBOOK.md`).
- [x] **15 Documentation accuracy** — every rake task, script and file named in README/SOLUTION/runbook exists (checked mechanically); claims re-verified against the code after the review fixes; benchmark figures quoted on the Safeguards page are tested against the committed report.

### PII inventory

| Data | Where | Retention / deletion |
|---|---|---|
| Employee name, e-mail, department | `employees` | operator-managed; never in exports or logs |
| Assessment answers (incl. free text) | `assessments.responses_json` | operator-managed; free text never leaves the DB |
| Admin name, e-mail, password digest (bcrypt) | `admins` | provisioned by an operator |
| Session token digests | `admin_sessions` | 8 h idle; purged hourly |
| Generated CSV (no PII beyond a pseudonymous ref) | Active Storage | 24 h link, file purged daily |

## Not verifiable in this environment

- ⚠️ **Docker build** — no Docker here. The Dockerfile installs Node, runs `npm ci`, precompiles and removes `node_modules`. *Verify:* `docker build .` and boot the image with `DATABASE_URL` and `RAILS_MASTER_KEY`.
- ⚠️ **S3 storage** — needs AWS credentials. *Verify:* set `ACTIVE_STORAGE_SERVICE=amazon` with the `AWS_*` variables on a staging app, request an export, download it.
- ⚠️ **A real Heroku deploy** (release phase, worker dyno, preboot). *Verify:* `heroku create`, push, check `heroku ps` shows `web` and `worker`.
- ⚠️ **TLS in a browser** — verified with a simulated `X-Forwarded-Proto` header; the browser pane would not store a `Secure` cookie over plain HTTP, as expected. *Verify:* open the staging URL over HTTPS.
- ⚠️ **Screen reader and 200% text zoom** — keyboard behaviour and semantics were verified, but no screen reader (VoiceOver/NVDA) run and no zoom test. *Verify:* VoiceOver on the sign-in page (text question) and the export dialog.
- ⚠️ **Lighthouse / Core Web Vitals** and **coverage percentages** — no tooling installed. *Verify:* `npx lighthouse` on the staging URL; add `simplecov` if a threshold is wanted.
- ⚠️ **A production-sized table beyond the 300k/1.2M-row benchmark**, **the Loom video**, and **any push to GitHub** (no remote is configured).

## Accepted known issues (P3 only, user sign-off required)

*None are accepted yet. These are the items I would like you to sign off, or tell me to fix:*

1. **Touch targets under 44 px** (filter chips, small buttons): taken from the design for a desktop admin tool; phone width is usable but not touch-optimised.
2. **No privacy policy or terms page** in the app. The cookie dialog documents the cookies and the Safeguards page the data handling; the legal text is the operator's to supply.
3. **No crash-reporting or uptime-alerting service** wired (Sentry, a pager): needs an external account. Errors are logged without PII and `/up` exists for a monitor.
4. **No global database `statement_timeout`.** Every dashboard query is bounded by design and the backfill sets its own timeouts; a global value would also affect migrations.
5. **English only**, no i18n.
6. **No self-service account deletion**: admins are provisioned by an operator; there is no signup.
7. **Scaffold Kamal config** (`config/deploy.yml`, placeholder host) is left in place; the Heroku-like path is the documented one.
8. **The accessible CAPTCHA alternative is weaker than the image** (a sum is easier for a program). Defence is the per-address and per-account rate limits; swapping to Turnstile or hCaptcha is a drop-in behind `Captcha.verify?`.

## Feature → test map

| Feature | Tests (count) | Failure paths covered |
|---|---|---|
| Sign-in, sessions, revocation, idle expiry | `authentication_test` (17) | wrong password = unknown e-mail, malformed input, replayed/copied cookie, idle, background polls |
| CAPTCHA (image and text) | `captcha_test` (22) | wrong/missing/malformed/expired/reused/replayed, forged ids |
| Cookie consent and preferences | `cookie_consent_test` (6), `cookie_preferences_test` (8) | forged cookies, loose boolean, withdrawal, off-site redirect |
| Tenancy and dashboard (filters, paging, score, drawer, update) | `assessments_dashboard_test` (30) | other tenant, rival `company_id`, bad dates/status, backwards range, blank status, foreign employee |
| Score rules | `score_calculator_test` (10) | missing/garbage/out-of-range/hex/NaN sections |
| Status write path | `status_test` (6), `assessment_test` (9) | unknown, blank, aliases, legacy rows |
| Backfill (plan only) | `status_backfill_test` (19) | rollback edits, NULL sentinel, constraint present, resume, missing column |
| Export request/download/retry | `exports_test` (29) | other tenant, bad input, cap, expired, not ready, stalled, forged link, logs |
| Export file and job | `assessment_exports_builder_test` (15), `assessment_export_test` (12) | redaction, CSV injection, time budget, generic failure, foreign employee, SQL never reads names |
| Release plan and tester | `release_plan_test` (4 + 7) | oversized/odd input, tester vs real save path |
| Safeguards | `safeguards_test` (2 + 5) | log line from the real filter |
| Log hygiene | `log_hygiene_test` (7) | PII in params, query string, SQL binds, sign-in, inspect |
| Indexes | `dashboard_indexes_test` (2) | accidental removal |
| Security hardening | `security_hardening_test` (9) | upload routes, signed link in logs, ephemeral disk, ops pages |
| Seeds | `seeds_test` (5) | idempotence, design parity |
| Production boot | `production_boot_test` (3) | initializer errors, ephemeral disk without object storage |
| Employee reference | `employee_ref_test` (4) | stability, per-company, non-derivable |
