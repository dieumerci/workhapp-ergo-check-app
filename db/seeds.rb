# Demo data for local development, review and the recorded walkthrough.
#
#   bin/rails db:seed
#
# Sign in with the accounts listed in README.md (printed again at the end of the
# run). The demo password can be changed with DEMO_ADMIN_PASSWORD.
#
# Production is skipped unless ALLOW_DEMO_SEED=true, so a deploy that runs
# `db:seed` on every release never plants demo accounts by accident. Skipping
# quietly (rather than aborting) keeps that deploy step green. To host a demo
# on purpose, set ALLOW_DEMO_SEED=true and choose DEMO_ADMIN_PASSWORD yourself.
if Rails.env.production? && ENV["ALLOW_DEMO_SEED"] != "true"
  puts "Skipping demo data in production (set ALLOW_DEMO_SEED=true to load it)."
  return
end

require_relative "seeds/demo_data"

DemoData.run
