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
      assert Admin.authenticate_by(email: email, password: DemoData::DEMO_PASSWORD), "#{email} should be able to sign in"
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

  private

  def in_production(allow: nil)
    previous = ENV["ALLOW_DEMO_SEED"]
    allow ? ENV["ALLOW_DEMO_SEED"] = allow : ENV.delete("ALLOW_DEMO_SEED")
    Rails.env.stub(:production?, true) { yield }
  ensure
    previous ? ENV["ALLOW_DEMO_SEED"] = previous : ENV.delete("ALLOW_DEMO_SEED")
  end
end
