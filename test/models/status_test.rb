require "test_helper"

class StatusTest < ActiveSupport::TestCase
  test "canonical values normalise to themselves" do
    Status::CANONICAL.each { |value| assert_equal value, Status.normalize(value) }
  end

  test "known legacy aliases map to a canonical value" do
    {
      "complete" => "completed", "comp" => "completed", "done" => "completed",
      "n/a" => "pending", "nil" => "pending", "null" => "pending", "" => "pending", nil => "pending"
    }.each do |raw, expected|
      assert_equal expected, Status.normalize(raw), "expected #{raw.inspect} to normalise to #{expected}"
    end
  end

  test "matching ignores case and surrounding whitespace" do
    assert_equal "archived", Status.normalize("ARCHIVED")
    assert_equal "completed", Status.normalize("  Done ")
  end

  test "unknown values do not normalise" do
    assert_nil Status.normalize("xyz")
    assert_nil Status.normalize("in progress")
    assert_not Status.known?("finished")
  end

  test "classify sends unknown values to needs follow-up instead of guessing completed" do
    assert_equal "needs_follow_up", Status.classify("xyz")
    assert_equal "completed", Status.classify("comp")
  end

  test "only completed, follow-up and archived assessments are scored" do
    assert_equal %w[completed needs_follow_up archived].sort, Status::SCORED.sort
    assert_not Status.scored?("pending")
    assert_not Status.scored?("in_progress")
  end
end
