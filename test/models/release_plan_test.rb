require "test_helper"

class ReleasePlanTest < ActiveSupport::TestCase
  test "the mapping is built from Status, so it can never describe different rules" do
    by_target = ReleasePlan.mapping.group_by { |row| row[:to] }

    assert_equal [ "completed", "complete", "comp", "done" ], by_target["completed"].first[:from]
    Status::ALIASES.each do |raw, target|
      shown = raw.empty? ? '""' : raw
      assert(ReleasePlan.mapping.any? { |row| row[:to] == target && row[:from].include?(shown) }, "#{raw.inspect} -> #{target} missing")
    end
    assert_equal Status::UNKNOWN_TARGET, ReleasePlan.mapping.last[:to]
  end

  test "all five statuses appear as targets" do
    assert_equal Status::CANONICAL.sort, ReleasePlan.mapping.map { |row| row[:to] }.uniq.sort
  end

  test "there are eight steps and the two that need a window are tagged" do
    steps = ReleasePlan.steps

    assert_equal 8, steps.size
    assert_equal [ "Add CHECK constraint as NOT VALID", "Drop status_legacy after 14 stable days" ], steps.select(&:window).map(&:title)
  end

  test "the backup comes first and the destructive step comes last" do
    assert_match(/backup/i, ReleasePlan.steps.first.title)
    assert_match(/Drop status_legacy/, ReleasePlan.steps.last.title)
  end

  test "there is a rollback for every stage" do
    assert_equal [ "During backfill", "After backfill", "Last resort" ], ReleasePlan.rollback.map { |rung| rung[:when] }
  end

  test "the tester explains each kind of value" do
    {
      "comp" => [ "completed", true, /Known alias/ ],
      "done" => [ "completed", true, /Known alias/ ],
      "n/a" => [ "pending", true, /Blank or not applicable/ ],
      "" => [ "pending", true, /Blank or not applicable/ ],
      "archived" => [ "archived", true, /Already valid/ ],
      "ARCHIVED" => [ "archived", true, /Known alias/ ],
      "xyz" => [ "needs_follow_up", false, /Unknown value/ ]
    }.each do |raw, (backfill, accepted, why)|
      result = ReleasePlan.normalize(raw)
      assert_equal backfill, result[:backfill][:status], raw
      assert_equal accepted, result[:save][:accepted], raw
      assert_match why, result[:backfill][:why], raw
    end
  end

  test "the tester agrees with the real save path" do
    [ "comp", "done", "xyz", "Archived", "pending", "in progress", "" ].each do |raw|
      company = create_company(name: "Tester #{raw.hash}")
      assessment = Assessment.new(company: company, employee: create_employee(company: company), status: raw)

      assert_equal assessment.valid?, ReleasePlan.normalize(raw)[:save][:accepted], raw.inspect
      assert_equal assessment.status, ReleasePlan.normalize(raw)[:save][:status] if assessment.valid?
    end
  end
end
