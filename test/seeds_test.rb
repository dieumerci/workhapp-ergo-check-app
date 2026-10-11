require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  setup do
    capture_io { load Rails.root.join("db/seeds.rb") }
    @northwind = Company.find_by!(name: "Northwind Logistics")
    @harbor = Company.find_by!(name: "Harbor & Pine Clinics")
    @summit = Company.find_by!(name: "Summit Physio Group")
  end

  test "Northwind reproduces the design's dataset" do
    tally = @northwind.assessments.map { |assessment| Status.classify(assessment.status) }.tally

    assert_equal 64, @northwind.assessments.count
    assert_equal({ "pending" => 6, "in_progress" => 10, "completed" => 29, "needs_follow_up" => 14, "archived" => 5 }, tally)
  end

  test "a second tenant exists with its own admin and data" do
    assert_equal 24, @harbor.assessments.count
    assert_equal 1, @harbor.admins.count
    assert_empty @harbor.assessments.where(employee_id: @northwind.employees.select(:id))
  end

  test "a third tenant adds more data without touching the other two" do
    assert_equal 40, @summit.assessments.count
    assert_equal 1, @summit.admins.count
    assert_empty @summit.assessments.where(employee_id: (@northwind.employees.pluck(:id) + @harbor.employees.pluck(:id)))
    assert_equal 5, @summit.assessments.map { |assessment| Status.classify(assessment.status) }.uniq.size
  end

  test "Northwind has two admins who share one company" do
    assert_equal %w[daniel.osei@northwind.example maya.reyes@northwind.example], @northwind.admins.order(:email).pluck(:email)
  end

  test "legacy mess is present so the dashboard and export have something to cope with" do
    raw = @northwind.assessments.pluck(:status).uniq

    assert_includes raw, "comp"
    assert_includes raw, "done"
    assert_includes raw, nil
    assert_includes raw, ""
    assert_includes raw, "on hold"
  end

  test "running the seeds again does not duplicate anything" do
    assert_no_difference -> { Assessment.count + Employee.count + Admin.count + Company.count } do
      capture_io { load Rails.root.join("db/seeds.rb") }
    end
  end

  test "every demo admin can authenticate" do
    %w[maya.reyes@northwind.example daniel.osei@northwind.example jonas.weber@harborpine.example aisha.bello@summitphysio.example].each do |email|
      assert Admin.authenticate_by(email: email, password: DemoData.password), "#{email} should be able to sign in"
    end
  end

  # ---- production --------------------------------------------------------

  test "production skips the demo data quietly unless ALLOW_DEMO_SEED=true" do
    Admin.where(email: "aisha.bello@summitphysio.example").delete_all

    output, = capture_io { in_production { load Rails.root.join("db/seeds.rb") } }
    assert_match(/Skipping demo data in production/, output)
    assert_nil Admin.find_by(email: "aisha.bello@summitphysio.example")

    capture_io { in_production(allow: "true") { load Rails.root.join("db/seeds.rb") } }
    assert Admin.find_by(email: "aisha.bello@summitphysio.example")
  end

test "ALLOW_DEMO_SEED accepts the usual spellings of yes, and nothing else" do
  email = "aisha.bello@summitphysio.example"

  [ "true", "TRUE", "True", " true ", "1", "yes", "on", "\"true\"" ].each do |value|
    Admin.where(email: email).delete_all
    capture_io { in_production(allow: value) { load Rails.root.join("db/seeds.rb") } }
    assert Admin.find_by(email: email), "ALLOW_DEMO_SEED=#{value.inspect} should load the demo data"
  end

  [ "false", "0", "no", "off", "", "nope" ].each do |value|
    Admin.where(email: email).delete_all
    capture_io { in_production(allow: value) { load Rails.root.join("db/seeds.rb") } }
    assert_nil Admin.find_by(email: email), "ALLOW_DEMO_SEED=#{value.inspect} should not load the demo data"
  end
end

test "a skipped production seed shows what the variable actually contained" do
  output, = capture_io { in_production(allow: "maybe") { load Rails.root.join("db/seeds.rb") } }

  assert_includes output, %(ALLOW_DEMO_SEED is "maybe")
end

test "the demo admins' password follows DEMO_ADMIN_PASSWORD every time the seeds run" do
  email = "maya.reyes@northwind.example"
  original = ENV["DEMO_ADMIN_PASSWORD"]
  ENV["DEMO_ADMIN_PASSWORD"] = "a-brand-new-demo-password"

  capture_io { load Rails.root.join("db/seeds.rb") }

  assert Admin.authenticate_by(email: email, password: "a-brand-new-demo-password"), "the account should now use the configured password"
  assert_nil Admin.authenticate_by(email: email, password: "ergocheck-demo-2026"), "the old password should no longer work"
  assert_equal 2, Admin.where(company: Company.find_by!(name: "Northwind Logistics")).count, "no admin should be duplicated"
ensure
  original ? ENV["DEMO_ADMIN_PASSWORD"] = original : ENV.delete("DEMO_ADMIN_PASSWORD")
end

test "a blank DEMO_ADMIN_PASSWORD falls back to the documented default" do
  original = ENV["DEMO_ADMIN_PASSWORD"]
  ENV["DEMO_ADMIN_PASSWORD"] = "   "

  assert_equal "ergocheck-demo-2026", DemoData.password
ensure
  original ? ENV["DEMO_ADMIN_PASSWORD"] = original : ENV.delete("DEMO_ADMIN_PASSWORD")
end

test "production never prints the demo password into the log" do
  original = ENV["DEMO_ADMIN_PASSWORD"]
  ENV["DEMO_ADMIN_PASSWORD"] = "do-not-print-this-password"
  output, = capture_io { in_production(allow: "true") { load Rails.root.join("db/seeds.rb") } }

  assert_not_includes output, "do-not-print-this-password"
  assert_includes output, "DEMO_ADMIN_PASSWORD"
ensure
  original ? ENV["DEMO_ADMIN_PASSWORD"] = original : ENV.delete("DEMO_ADMIN_PASSWORD")
end

  private

  def in_production(allow: nil)
    previous = ENV["ALLOW_DEMO_SEED"]
    allow ? ENV["ALLOW_DEMO_SEED"] = allow : ENV.delete("ALLOW_DEMO_SEED")
    Rails.env.stub(:production?, true) { yield }
  ensure
    previous ? ENV["ALLOW_DEMO_SEED"] = previous : ENV.delete("ALLOW_DEMO_SEED")
  end
end
