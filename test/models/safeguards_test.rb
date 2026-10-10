require "test_helper"

class SafeguardsTest < ActiveSupport::TestCase
  test "the after line comes from the real parameter filter" do
    after = Safeguards.log_example[:after]

    assert_includes after, '"employee_email"=>"[FILTERED]"'
    assert_includes after, '"responses_json"=>"[FILTERED]"'
    assert_includes after, '"status"=>"completed"'
    assert_includes after, '"from"=>"2026-09-01"'
    assert_not_includes after, "amara@example.com"
    assert_not_includes after, "lower back pain"
  end

  test "the before line is the legacy raw one and carries a company id" do
    before = Safeguards.log_example[:before]

    assert_includes before, "amara@example.com"
    assert_includes before, '"company_id"=>"42"'
  end

  test "the current request can no longer carry a company id" do
    assert_not_includes Safeguards::CURRENT_PARAMS.keys, "company_id"
  end

  test "there is a card for each task plus sign-in" do
    assert_equal [ "Task 1 · Export", "Task 2 · Dashboard", "Task 2 · Score", "Task 3 · Status", "Access · Sign-in" ], Safeguards.cards.map(&:task)
  end

  test "the benchmark numbers quoted on the page match the committed report" do
    report = File.read(Rails.root.join("benchmarks/dashboard-2026-10-10.txt"))
    dashboard = Safeguards.cards.find { |card| card.title == "Faster on large data" }.points.join(" ")

    assert_match(/300001/, report)
    assert_match(/300,001 queries/, dashboard)
  end
end
