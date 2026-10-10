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
- [ ] 3.4 Every query goes through `Current.company` (no client-supplied company identifier anywhere)
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
- [ ] 5.7 Log hygiene: filtered parameters, filtered attributes, no raw responses in logs

## 6. Task 1 — Company-scoped CSV export

- [ ] 6.1 `assessment_exports` table, model, state machine (queued → processing → ready / failed)
- [ ] 6.2 Background job builds the CSV in batches, updates progress, fails safely with a generic reason
- [ ] 6.3 Exactly two filters (date range, status); six redacted columns; one-way `employee_ref`; CSV-injection guard
- [ ] 6.4 Download is tenant-checked and expires after 24 hours
- [ ] 6.5 Export modal: locked company, match count, validation, in-progress / ready states
- [ ] 6.6 Exports page: history, progress bars, download, retry, nav badge, polling

## 7. Task 3 — Plan-only backfill and release plan

- [ ] 7.1 Release plan page: mapping, live normalizer tester, 8 steps with live/window tags, rollback ladder
- [ ] 7.2 Backfill designed but not executed (`status:backfill:report` read-only, `status:backfill:run` guarded)
- [ ] 7.3 Backup / release / rollback runbook for a Heroku-like environment

## 8. Safeguards page

- [ ] 8.1 Four safeguard cards + before/after request log line (produced by the real parameter filter)

## 9. Quality gates (zero warnings)

- [ ] 9.1 Automated tests: tenancy, export redaction, filters, score, status, auth, CAPTCHA, cookies
- [ ] 9.2 `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `npm run check` all clean
- [ ] 9.3 Browser walkthrough of every screen against the design screenshots

## 10. Deliverables

- [ ] 10.1 `README.md` — how to run locally and how everything works
- [ ] 10.2 `SOLUTION.md` — design, trade-offs, measurements, release/rollback plan, build log with reasons
- [ ] 10.3 This checklist fully ticked
- [ ] 10.4 Loom demo (owner records this — see README "Demo script")

## Out of scope (quarantined)

Nothing quarantined yet.
