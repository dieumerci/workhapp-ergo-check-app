require "test_helper"
require "open3"

# Development and test never run the production-only initializers, eager loading,
# the production queue/cache adapters or the CSP, so a mistake there passes every other
# test and breaks the first deploy. These tests boot the real production environment in a
# subprocess (no database connection is needed) and check the outcome.
class ProductionBootTest < ActiveSupport::TestCase
  BOOT = [ "bin/rails", "runner", 'puts "BOOT_OK queue=#{ActiveJob::Base.queue_adapter.class.name.split("::").last}"' ].freeze

  def boot(env = {})
    clean = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "DATABASE_URL" => "postgres:///workhappy_never_connected",
              "DYNO" => nil, "ACTIVE_STORAGE_SERVICE" => nil }
    Open3.capture3(clean.merge(env), *BOOT, chdir: Rails.root.to_s)
  end

  test "the app boots in production, eager loaded, with the real queue adapter" do
    stdout, stderr, status = boot

    assert status.success?, "production boot failed:\n#{stderr.lines.first(8).join}"
    assert_match(/BOOT_OK queue=SolidQueueAdapter/, stdout)
  end

  test "a Heroku-like platform without object storage refuses to boot, with a clear reason" do
    _stdout, stderr, status = boot("DYNO" => "web.1")

    assert_not status.success?
    assert_match(/ACTIVE_STORAGE_SERVICE is not set/, stderr)
  end

  test "a Heroku-like platform with object storage configured boots" do
    s3 = { "ACTIVE_STORAGE_SERVICE" => "amazon", "AWS_S3_BUCKET" => "example-exports", "AWS_ACCESS_KEY_ID" => "AKIAEXAMPLE",
           "AWS_SECRET_ACCESS_KEY" => "example-secret", "AWS_REGION" => "eu-west-1" }
    stdout, stderr, status = boot({ "DYNO" => "web.1" }.merge(s3))

    assert status.success?, "boot failed:\n#{stderr.lines.first(8).join}"
    assert_match(/BOOT_OK/, stdout)
  end
end
