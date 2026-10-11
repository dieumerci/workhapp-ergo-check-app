require "test_helper"

# config/database.yml once had its `production:` header commented out (it sat inside Rails'
# template comment), so the `url:` line below it belonged to `test:` and production had no
# configuration of its own. Production only worked when DATABASE_URL happened to be set, and
# every earlier check set it. These tests read the file itself.
class DatabaseConfigTest < ActiveSupport::TestCase
  CONFIG = YAML.safe_load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true).freeze

  test "production has its own block, which takes its connection from DATABASE_URL" do
    assert CONFIG.key?("production"), "config/database.yml has no production: block"
    assert_equal "postgresql", CONFIG.dig("production", "adapter")
    assert CONFIG["production"].key?("url"), "production should read its connection from DATABASE_URL"
  end

  test "test and development do not read DATABASE_URL from the file" do
    assert_not CONFIG["test"].key?("url")
    assert_not CONFIG["development"].key?("url")
  end

  test "every environment is configured" do
    assert_equal %w[development production test], (CONFIG.keys - %w[default]).sort
  end
end
