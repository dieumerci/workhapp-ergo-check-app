# The ergonomic score of an assessment.
#
# Rule (from the design): the score is the rounded average of the four section
# scores. It is only produced when all four sections hold a usable number, so
# the dashboard can never show a blank, a NaN or a number computed from
# partial data. Anything that cannot be scored honestly returns nil, which the
# UI renders as "Not scored yet".
#
# Legacy rows are tolerated: a section stored as the string "74" still counts;
# a missing, non-numeric or out-of-range (<0, >100) section does not.
module ScoreCalculator
  SECTIONS = {
    "workstation_setup" => "Workstation setup",
    "posture_movement" => "Posture & movement",
    "breaks_recovery" => "Breaks & recovery",
    "discomfort_reported" => "Discomfort reported"
  }.freeze

  RANGE = (0..100).freeze

  module_function

  # +raw+ is the "section_scores" object from responses_json (or nil).
  # Returns { "workstation_setup" => 74, ... } with nil for unusable sections.
  def sections(raw)
    raw = {} unless raw.is_a?(Hash)
    SECTIONS.keys.index_with { |key| coerce(raw[key]) }
  end

  # Rounded average of the four sections, or nil if any section is unusable.
  def score(raw)
    values = sections(raw).values
    return if values.any?(&:nil?)

    (values.sum / values.size.to_f).round
  end

  def coerce(value)
    number =
      case value
      when Integer, Float then value
      # Decimal digits only. Ruby's Float() also accepts "0x1A" (26.0) and "1e2" (100.0),
      # which are not scores.
      when String then (text = value.strip).match?(/\A\d+(\.\d+)?\z/) ? Float(text) : nil
      end
    return unless number.is_a?(Numeric) && number.finite? && RANGE.cover?(number)

    number
  end
  private_class_method :coerce
end
