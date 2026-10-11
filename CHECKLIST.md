# ErgoCheck — Delivery Checklist

Single source of truth for what has to be built and whether it is done. Mirrors
`.claude-checklist.json` (the machine-readable copy used by the delivery pipeline).
A box is only ticked after the work is **implemented, verified, committed and merged**.

Legend: `[x]` done and merged · `[ ]` pending

## Sources of truth

| Source | What it contributes |
|---|---|
| `Senior_Full_Stack_Developer__Ruby_on_Rails__Assignment.pdf` | Tasks 1–3, constraints, deliverables |
| Claude Design bundle (`assessments-admin-app/project/`) | Every screen, state, colour, copy string |
| Owner's extra requests | Cookie consent feature, CAPTCHA feature, README + SOLUTION docs, this checklist |

## 1. Foundation

- [x] 1.1 Baseline Rails 8.1 + Inertia + React + TypeScript + Vite scaffold committed
- [x] 1.2 PostgreSQL schema: companies, employees, assessments (+ migrations, models, associations); admins arrive with sign-in in 3.1

## 2. Task 3 (write path) — only five statuses go in

- [x] 2.1 `Status` value object: five canonical values, alias table, `normalize`
- [x] 2.2 `Assessment` normalises aliases on save and rejects unknown values (create and update)

## 3. Identity, tenancy, cookies, CAPTCHA

- [x] 3.1 Company-admin sign-in / sign-out, `Current.company` derived from the session, rate-limited
- [x] 3.2 CAPTCHA on sign-in (server-rendered PNG, digest in session, single use, expiring)
- [x] 3.3 Cookie consent: signed consent cookie, banner + settings dialog, opt-in "remember my filters" cookie store (wired to the dashboard in 5.1)
- [x] 3.4 Every query goes through `Current.company` (no client-supplied company identifier anywhere)
- [x] 3.5 Seed data: two tenants, 64 Northwind assessments matching the design, deliberately messy legacy statuses

## 4. UI shell (from the design)

- [x] 4.1 Tailwind theme tokens, self-hosted Instrument Sans / IBM Plex Mono, app layout (sidebar, company badge, toasts)
- [x] 4.2 Sign-in page in the same visual language

## 5. Task 2 — Dashboard

- [x] 5.1 Assessments page: status chips with counts, date presets, From/To, clear filters, empty state, skeleton, paging (10/page)
- [x] 5.2 Server-side filtering + pagination; status filter works on messy legacy values
- [x] 5.3 Score is always the rounded mean of four section scores; "Not scored yet" otherwise
- [x] 5.4 Detail drawer (sections breakdown, status control, toast on save)
- [x] 5.5 Two dashboard indexes built concurrently: `(company_id, created_at DESC, id DESC)` for the page, `(company_id, status, created_at DESC)` for the counts
- [x] 5.6 Reproducible benchmark (`rake perf:seed`, `rake perf:benchmark`) with before/after numbers
- [x] 5.7 Log hygiene: filtered parameters, filtered attributes, no raw responses in logs

## 6. Task 1 — Company-scoped CSV export

- [x] 6.1 `assessment_exports` table, model, state machine (queued → processing → ready / failed)
- [x] 6.2 Background job builds the CSV in batches, updates progress, fails safely with a generic reason
- [x] 6.3 Exactly two filters (date range, status); six redacted columns; one-way `employee_ref`; CSV-injection guard
- [x] 6.4 Download is tenant-checked and expires after 24 hours
- [x] 6.5 Export modal: locked company, match count, validation, in-progress / ready states
- [x] 6.6 Exports page: history, progress bars, download, retry, nav badge, polling

## 7. Task 3 — Plan-only backfill and release plan

- [x] 7.1 Release plan page: mapping, live normalizer tester, 8 steps with live/window tags, rollback ladder
- [x] 7.2 Backfill designed but not executed (`status:backfill:report` read-only, `status:backfill:run` guarded)
- [x] 7.3 Backup / release / rollback runbook for a Heroku-like environment (`db/release_plan/RUNBOOK.md`, SOLUTION §6)

## 8. Safeguards page

- [x] 8.1 Four safeguard cards + before/after request log line (produced by the real parameter filter)

## 9. Quality gates (zero warnings)

- [x] 9.1 Automated tests (255): tenancy, export redaction, filters, score, status, backfill, auth, sessions, CAPTCHA, cookies, logs, hardening, new assessment, seeds
- [x] 9.2 `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `npm run check` all clean
- [x] 9.3 Browser walkthrough of every screen against the design screenshots
- [x] 9.4 Production configuration verified by booting production mode: single database, Solid Queue worker building an export, SSL headers, CSP with nonce, no signed links in logs

## 10. Deliverables

- [x] 10.1 `README.md` — how to run locally and how everything works
- [x] 10.2 `SOLUTION.md` — design, trade-offs, measurements, release/rollback plan, build log with reasons
- [x] 10.3 This checklist fully ticked (10.4 is the owner's)
- [ ] 10.4 Loom demo (owner records this — see README "Demo script")

## 11. Independent review and production-readiness audit (all fixed)

Findings raised by an independent read-only reviewer and by the audit; full detail and evidence in
`docs/PRODUCTION_AUDIT_CHECKLIST.md`.

- [x] 11.1 CAPTCHA single-use and sessions revocable: state moved server-side (AUD-v1-001)
- [x] 11.2 Exports whose worker died: heartbeat, takeover, reaper, live-only cap, preview throttle (AUD-v1-002, 006)
- [x] 11.3 Data correctness and redaction: blank status, dedicated export select, tenant-pinned join, score parsing, 48-bit refs (AUD-v1-005, 011, 012, 016, 017)
- [x] 11.4 Security: unused upload routes closed, signed links out of logs, ephemeral-disk guard, ops pages gated (AUD-v1-003, 007, 014, 015)
- [x] 11.5 Backfill rollback leaves later edits alone (AUD-v1-004)
- [x] 11.6 Accessibility and resilience: contrast, dialog focus/inert, error boundary, consent clears local storage (AUD-v1-008, 009, 013, 018)
- [x] 11.7 Accessible text alternative to the image CAPTCHA (AUD-v1-010)
- [x] 11.8 Hygiene: `.env.example`, CI seeds step, lockfile (AUD-v1-019, 020, 021)
- [x] 11.9 Production-readiness audit written (`docs/PRODUCTION_AUDIT_CHECKLIST.md`); 8 low-severity items await owner sign-off
- [x] 11.10 Production boot guarded by a subprocess test after the final gate found it broken (AUD-v1-023)
- [x] 11.11 Release prep: `CHANGELOG.md` and version `0.1.0` (tag is the owner's to create)

## 12. Owner follow-ups (2026-10-11)

- [x] 12.1 Click-through of every screen as a user; the missing piece was a way to create data, so a tenant-safe **New assessment** flow was added (`ae41044`)
- [x] 12.2 Richer seed data: a third tenant (Summit Physio Group) and a second Northwind admin; production skips seeds unless `ALLOW_DEMO_SEED=true` (`a960fdb`)
- [x] 12.3 Log leaks found by the new tests and the production-mode gate, and fixed: bare `name` and `scores` filtered, dev query log tags off (SOLUTION §12)
- [x] 12.4 Run on another port documented (`PORT=4000 bin/dev`, `VITE_RUBY_PORT` for Vite)
- [x] 12.5 `README.md` rewritten: what the app is, architecture, demo logins, "is it fully functional", why not Devise, Railway steps
- [x] 12.6 `APP_GUIDE.md`: plain-language tour, settings, everyday tasks, troubleshooting
- [x] 12.7 `railway.json` (Dockerfile build, pre-deploy database steps, `/up` healthcheck); **not executed on Railway**
- [x] 12.8 Two git-ignored local files: `LOOM_VIDEO_SCRIPT.md` (talk track) and `INTERVIEW_PREP.md` (code tour and likely questions)
- [x] 12.9 Every requirement in the assignment PDF re-checked against the running app and the tests (SOLUTION §2)
- [x] 12.11 `RAILWAY_SETUP.md`: every environment variable, dashboard and CLI steps, checks, troubleshooting; `railway.json` corrected to one pre-deploy command and guarded by a test
- [x] 12.12 `INTERVIEW_PREP.md` expanded into a detailed, code-level study guide (git-ignored)
- [ ] 12.10 Push to GitHub: waiting for the owner's go-ahead (no remote is configured)

## Out of scope (quarantined)

Nothing quarantined yet.
