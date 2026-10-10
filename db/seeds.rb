# Demo data for local development. Safe to run repeatedly.
#
#   bin/rails db:seed
#
# Sign in with the accounts listed in README.md. The demo password can be
# changed with DEMO_ADMIN_PASSWORD. Never seed demo accounts in production.
abort "Refusing to seed demo accounts in production." if Rails.env.production?

require_relative "seeds/demo_data"

DemoData.run
