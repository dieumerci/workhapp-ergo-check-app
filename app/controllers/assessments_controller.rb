class AssessmentsController < InertiaController
  FILTER_KEYS = %i[status preset from to].freeze
  EMPLOYEE_OPTION_LIMIT = 500

  rate_limit to: 30, within: 1.minute, only: :create, with: -> {
    redirect_back_or_to assessments_path, alert: "Too many new assessments in a short time. Please wait a moment."
  }

  # Searching runs a company-wide lookup for every pause in typing, so it is limited too.
  rate_limit to: 180, within: 1.minute, only: :index, if: -> { params[:q].present? }, name: "search", with: -> {
    redirect_to assessments_path, alert: "Too many searches in a short time. Please wait a moment."
  }

  def index
    filters = dashboard_filters
    remember(filters) if explicit_filters?

    # Props are lambdas so a partial reload (opening the detail drawer asks
    # only for `selected`) does no dashboard work at all.
    dashboard = nil
    result = -> { dashboard ||= AssessmentDashboard.new(company: Current.company, filters: filters).call }

    render inertia: {
      filters: filters.to_h,
      assessments: -> { result.call.rows.map(&:to_list) },
      counts: -> { result.call.counts },
      legacy: -> { result.call.legacy&.to_h },
      pagination: -> {
        { page: result.call.page, pages: result.call.pages, total: result.call.total, per_page: AssessmentDashboard::PER_PAGE }
      },
      selected: -> { selected_detail },
      # Only the "New assessment" dialog asks for these (a partial reload when it
      # opens), so the dashboard itself never pays for the employee list.
      employees: InertiaRails.optional { employee_options }
    }
  end

  def create
    intake = NewAssessment.new(Current.company, params)

    if intake.save
      assessment = intake.assessment
      redirect_to assessments_path(selected: assessment.id), notice: "Assessment A-#{assessment.id} created"
    else
      redirect_back_or_to assessments_path, inertia: { errors: { assessment: intake.errors } }
    end
  end

  def update
    # Scoped to the signed-in admin's company: another tenant's id is a 404.
    assessment = Current.company.assessments.find(params[:id])
    target = assessments_path(selected: assessment.id)

    if assessment.update(status: params[:status].to_s)
      redirect_back_or_to target, notice: "Status updated to #{Status.label(assessment.status)}"
    else
      redirect_back_or_to target, alert: "Status must be one of: #{Status::CANONICAL.map { |value| Status.label(value) }.join(', ')}."
    end
  end

  private

  def explicit_filters?
    FILTER_KEYS.any? { |key| params.key?(key) }
  end

  # Explicit filters in the URL win. Without any, the remembered preference
  # cookie (only ever present with consent) supplies status and preset.
  def dashboard_filters
    source = explicit_filters? ? params : cookie_preferences.remembered_filters.merge(page: params[:page], q: params[:q])
    AssessmentDashboard::Filters.from_params(source)
  end

  def remember(filters)
    preset = filters.preset == "custom" ? "all" : filters.preset
    cookie_preferences.remember_filters(status: filters.status, preset: preset)
  end

  # The signed-in admin's own employees, for the "New assessment" picker.
  def employee_options
    Current.company.employees.order(:name, :id).limit(EMPLOYEE_OPTION_LIMIT).pluck(:id, :name, :department).map do |id, name, department|
      { id: id, name: name, department: department }
    end
  end

  def selected_detail
    return if params[:selected].blank?

    AssessmentRow.find(Current.company, params[:selected])&.to_detail
  end
end
