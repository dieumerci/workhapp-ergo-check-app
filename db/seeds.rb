# Demo data for local development, review and the recorded walkthrough.
#
#   bin/rails db:seed
#
# Sign in with the accounts listed in README.md (printed again at the end of the
# run). The demo password can be changed with DEMO_ADMIN_PASSWORD.
#
# Production is skipped unless ALLOW_DEMO_SEED is on (true, 1, yes or on, in any case,
# with stray spaces or quotes ignored), so a deploy that runs `db:seed` on every release
# never plants demo accounts by accident. Skipping quietly (rather than aborting) keeps
# that deploy step green, and the message says what the variable actually contained, so a
# typo is visible in the deploy log. To host a demo on purpose, set ALLOW_DEMO_SEED=true and
# choose DEMO_ADMIN_PASSWORD yourself; while it is on, every run re-applies that password.
allow_demo_seed = %w[true 1 yes on].include?(ENV["ALLOW_DEMO_SEED"].to_s.strip.delete("\"'").downcase)
if Rails.env.production? && !allow_demo_seed
  puts "Skipping demo data in production (ALLOW_DEMO_SEED is #{ENV['ALLOW_DEMO_SEED'].inspect}; set it to true to load it)."
  return
end

require_relative "seeds/demo_data"

DemoData.run
