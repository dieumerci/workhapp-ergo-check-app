# One assessment as the dashboard shows it: just the columns the page needs,
# employee joined in, scored by ScoreCalculator.
#
# The SELECT deliberately omits employee_email and the free-text parts of
# responses_json; only the small "section_scores" object is pulled out of the
# JSON column. Rows are never built from a full Assessment record.
module AssessmentRow
  Row = Struct.new(
    :id, :code, :employee_name, :employee_ref, :department, :created_on, :status, :score, :sections,
    keyword_init: true
  ) do
    def to_list
      {
        id: id, code: code, employee_name: employee_name, employee_ref: employee_ref,
        department: department, created_on: created_on, status: status,
        status_label: Status.label(status), score: score
      }
    end

    # Adds the breakdown the detail drawer shows.
    def to_detail
      to_list.merge(
        score_state: score_state,
        sections: score ? sections.map { |key, value| { key: key, label: ScoreCalculator::SECTIONS.fetch(key), value: value.round } } : []
      )
    end

    # scored: shown. awaiting_completion: not scorable yet by status.
    # incomplete: status says scored but section data is missing or unusable.
    def score_state
      return "scored" if score
      return "awaiting_completion" unless Status.scored?(status)

      "incomplete"
    end
  end

  COLUMNS = [
    "assessments.id", "assessments.company_id", "assessments.employee_id", "assessments.status",
    "assessments.created_at", "employees.name AS employee_name", "employees.department AS department",
    Arel.sql("assessments.responses_json -> 'section_scores' AS section_scores")
  ].freeze

  module_function

  # +scope+ must already be restricted to one company (company.assessments...).
  def relation(scope)
    scope.joins(:employee).select(*COLUMNS)
  end

  def find(company, id)
    record = relation(company.assessments).find_by(id: id)
    build(record) if record
  end

  def build(record)
    status = Status.classify(record.status)
    sections = ScoreCalculator.sections(record.section_scores)

    Row.new(
      id: record.id,
      code: "A-#{record.id}",
      employee_name: record.employee_name,
      employee_ref: EmployeeRef.for(company_id: record.company_id, employee_id: record.employee_id),
      department: record.department,
      created_on: record.created_at.in_time_zone.to_date.iso8601,
      status: status,
      score: Status.scored?(status) ? ScoreCalculator.score(record.section_scores) : nil,
      sections: sections
    )
  end
end
