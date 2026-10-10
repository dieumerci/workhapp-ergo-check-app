require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  setup do
    capture_io { load Rails.root.join("db/seeds.rb") }
    @northwind = Company.find_by!(name: "Northwind Logistics")
    @harbor = Company.find_by!(name: "Harbor & Pine Clinics")
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

  test "demo admins can authenticate" do
    assert Admin.authenticate_by(email: "maya.reyes@northwind.example", password: DemoData::DEMO_PASSWORD)
  end
end
