module AssessmentExports
  # The one place that turns an export's two filters into rows. The preview
  # count, the export request check and the file builder all use it, so the
  # number shown to the admin is always the number of rows that get exported.
  #
  # +company+ must come from the signed-in admin. There is no other input that
  # can widen the result.
  module Scope
    module_function

    def call(company, from:, to:, status:)
      relation = company.assessments
      range = date_range(from, to)
      relation = relation.where(created_at: range) if range
      return relation if status == "all"

      # Match every legacy spelling of the status (see Status.matching).
      raw_values = Status.matching(relation.group(:status).count.keys, status)
      relation.where(status: raw_values)
    end

    # Inclusive of the whole "to" day, in the application time zone.
    def date_range(from, to)
      return if from.nil? && to.nil?

      (from&.in_time_zone&.beginning_of_day)..(to&.in_time_zone&.end_of_day)
    end
  end
end
