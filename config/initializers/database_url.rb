# Production reads its whole database configuration from DATABASE_URL (see config/database.yml).
# Without it the app used to die deep inside Active Record with "The `production` database is not
# configured for the `production` environment", which says nothing about the cause. Stop early,
# with the fix in the message.
#
# Skipped for the image build, which precompiles assets with SECRET_KEY_BASE_DUMMY and no database.
if Rails.env.production? && ENV["DATABASE_URL"].blank? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  raise <<~MESSAGE.squish
    DATABASE_URL is not set, so the app has no database to connect to.
    On Railway, open the app service's Variables and add DATABASE_URL=${{Postgres.DATABASE_URL}}
    (the name inside ${{ }} must match your PostgreSQL service exactly), then redeploy.
    On Heroku, add a Postgres add-on, which sets it. Locally, export DATABASE_URL=postgres:///your_database.
    See RAILWAY_SETUP.md, section 3.
  MESSAGE
end
