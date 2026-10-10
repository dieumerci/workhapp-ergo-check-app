# Release plan SQL (plan only)

These scripts are the DDL steps of the status-normalization release. They are
**not** Rails migrations on purpose: `db:migrate` must never run part of this plan
by accident, and each step has to be run (and checked) by a person, in order.

Run one with `heroku pg:psql --app <app> < db/release_plan/<file>.sql`.
The full sequence, who runs what and when, and how to roll back each step are in
`SOLUTION.md` (section "Release and rollback plan") and `docs/release-runbook.md`.

| File | Release step | Safe while live? |
|---|---|---|
| `01_add_status_legacy.sql` | 3 | yes |
| `02_add_status_check_not_valid.sql` | 4 | low-traffic window (brief lock) |
| `03_validate_status_check.sql` | 6 | yes |
| `04_dashboard_indexes.sql` | 7 | yes (also shipped as a Rails migration) |
| `05_drop_status_legacy.sql` | 8 | low-traffic window |
| `rollback_drop_status_check.sql` | rollback | yes |
