require "test_helper"

class ScoreCalculatorTest < ActiveSupport::TestCase
  def sections(*values)
    SECTION_KEYS.zip(values).to_h
  end

  test "the score is the rounded average of the four sections" do
    assert_equal 75, ScoreCalculator.score(sections(80, 70, 75, 75))
    assert_equal 73, ScoreCalculator.score(sections(74, 70, 76, 71)) # 72.75
    assert_equal 87, ScoreCalculator.score(sections(87, 77, 88, 96)) # 87.0
  end

  test "exact halves round up, like the prototype's Math.round" do
    assert_equal 71, ScoreCalculator.score(sections(70, 70, 71, 71)) # 70.5
    assert_equal 73, ScoreCalculator.score(sections(72, 72, 73, 73)) # 72.5
    assert_equal 1, ScoreCalculator.score(sections(0, 0, 1, 1)) # 0.5
    assert_equal 100, ScoreCalculator.score(sections(99, 99, 100, 100)) # 99.5
  end

  test "quarters round to the nearest whole number" do
    assert_equal 71, ScoreCalculator.score(sections(70, 71, 71, 71)) # 70.75
    assert_equal 70, ScoreCalculator.score(sections(70, 70, 70, 71)) # 70.25
  end

  test "numeric strings from legacy rows still count" do
    assert_equal 74, ScoreCalculator.score(sections("74", " 70 ", 78, "74.0"))
  end

  test "floats are accepted" do
    assert_equal 75, ScoreCalculator.score(sections(74.5, 75.5, 75, 75))
  end

  test "a missing section means no score, never a partial average" do
    assert_nil ScoreCalculator.score(sections(80, 70, nil, 75))
    assert_nil ScoreCalculator.score({ "workstation_setup" => 80 })
  end

  test "unusable values mean no score" do
    [ "n/a", "", "abc", true, [], {}, -1, 101, 140, Float::NAN, Float::INFINITY, "0x1A", "1e2", "1_0", "٣٤", ".5", "7 4", "74,5" ].each do |bad|
      assert_nil ScoreCalculator.score(sections(80, 70, 75, bad)), "expected #{bad.inspect} to be unusable"
    end
  end

  test "the bounds are inclusive" do
    assert_equal 0, ScoreCalculator.score(sections(0, 0, 0, 0))
    assert_equal 100, ScoreCalculator.score(sections(100, 100, 100, 100))
  end

  test "garbage input never raises" do
    [ nil, "text", 42, [], [ 1, 2 ], true ].each do |bad|
      assert_nil ScoreCalculator.score(bad)
    end
  end

  test "sections returns a value or nil for each of the four sections" do
    assert_equal(
      { "workstation_setup" => 80, "posture_movement" => nil, "breaks_recovery" => 75.0, "discomfort_reported" => 70.0 },
      ScoreCalculator.sections(sections(80, "bad", "75", 70.0))
    )
  end
end
