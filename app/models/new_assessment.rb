# Creates one assessment for one company, from what the "New assessment" form sends.
#
# The company always comes from the caller (the signed-in admin's), never from
# the request. The employee is either one of that company's existing employees
# (another tenant's id is RecordNotFound, which the app answers with a 404) or a
# new one created in the same transaction, so a rejected assessment leaves no
# stray employee behind.
#
# Section scores are all-or-nothing, because ScoreCalculator refuses to average
# fewer than four: either four whole numbers from 0 to 100, or none at all. They
# are only kept for a status that shows a score (completed, needs follow-up,
# archived), so nothing is stored that the dashboard would never display. Free-text
# answers and e-mail addresses are not collected here at all.
class NewAssessment
  NEW_EMPLOYEE = "new".freeze
  NAME_LIMIT = 120
  DEPARTMENT_LIMIT = 80

  attr_reader :assessment, :errors

  def initialize(company, params)
    @company = company
    @params = params
    @errors = []
  end

  def save
    @errors = problems
    return false if errors.any?

    Assessment.transaction do
      @assessment = @company.assessments.new(employee: employee, status: status, responses_json: responses)
      @assessment.save!
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    false
  end

  private

  def status
    @params[:status].presence&.to_s || Status::PENDING
  end

  def new_employee?
    @params[:employee_id].to_s == NEW_EMPLOYEE
  end

  def employee_name
    @params[:employee_name].to_s.squish
  end

  def department
    @params[:department].to_s.squish.presence
  end

  # Checked before anything is written, so every mistake is reported at once.
  def problems
    list = []
    list << "Choose an employee." if @params[:employee_id].blank?
    if new_employee?
      list << "Enter the new employee's name." if employee_name.empty?
      list << "Employee name is too long (at most #{NAME_LIMIT} characters)." if employee_name.length > NAME_LIMIT
      list << "Department is too long (at most #{DEPARTMENT_LIMIT} characters)." if department.to_s.length > DEPARTMENT_LIMIT
    end
    list.concat(score_problems)
  end

  def employee
    return @company.employees.find(@params[:employee_id]) unless new_employee?

    @company.employees.create!(name: employee_name, department: department)
  end

  def raw_scores
    scores = @params[:scores]
    scores.respond_to?(:to_unsafe_h) ? scores.to_unsafe_h : {}
  end

  def entered_scores
    ScoreCalculator::SECTIONS.keys.index_with { |key| raw_scores[key].to_s.strip }
  end

  def scores_apply?
    Status.scored?(Status.classify(status))
  end

  def score_problems
    return [] unless scores_apply?

    values = entered_scores.values
    return [] if values.all?(&:empty?)
    return [ "Fill in all four section scores, or leave them all empty." ] if values.any?(&:empty?)
    return [ "Section scores must be whole numbers from 0 to 100." ] unless values.all? { |value| value.match?(/\A\d{1,3}\z/) && value.to_i <= 100 }

    []
  end

  def responses
    return {} unless scores_apply? && entered_scores.values.none?(&:empty?)

    { "section_scores" => entered_scores.transform_values(&:to_i) }
  end
end
