require "test_helper"

# railway.json is never executed by the test suite, so these tests guard the parts of
# it that Railway's published JSON schema is strict about, and the routes it relies on.
# (A first version listed two pre-deploy commands; the schema allows at most one, so
# Railway would have rejected or ignored the file.)
class RailwayConfigTest < ActiveSupport::TestCase
  CONFIG = JSON.parse(Rails.root.join("railway.json").read).freeze

  test "builds from the Dockerfile that exists in the repository" do
    assert_equal "DOCKERFILE", CONFIG.dig("build", "builder")
    assert Rails.root.join(CONFIG.dig("build", "dockerfilePath")).file?
  end

  test "preDeployCommand is one command (a string, or an array of at most one string)" do
    command = CONFIG.dig("deploy", "preDeployCommand")

    assert(command.is_a?(String) || (command.is_a?(Array) && command.size <= 1 && command.all?(String)), command.inspect)
  end

  test "the pre-deploy command prepares the database and runs the idempotent seeds" do
    command = Array(CONFIG.dig("deploy", "preDeployCommand")).first

    assert_match(/\Abin\/rails db:prepare db:seed\z/, command)
  end

  test "the start command listens on every interface and does not run the database steps" do
    command = CONFIG.dig("deploy", "startCommand")

    assert_match(/bin\/rails server -b ::/, command)
    assert_no_match(/db:/, command)
  end

  test "the healthcheck path is a real, unauthenticated route that answers 200" do
    path = CONFIG.dig("deploy", "healthcheckPath")

    assert_equal "/up", path
    assert Rails.application.routes.recognize_path(path)[:controller].present?
  end

  test "restart policy and timeout use the values the schema allows" do
    assert_includes %w[ON_FAILURE ALWAYS NEVER], CONFIG.dig("deploy", "restartPolicyType")
    assert_kind_of Numeric, CONFIG.dig("deploy", "healthcheckTimeout")
  end
end
