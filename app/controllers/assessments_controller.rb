class AssessmentsController < InertiaController
  FILTER_KEYS = %i[status preset from to].freeze

  def index
    filters = dashboard_filters
    remember(filters) if explicit_filters?

    # Props are lambdas so a partial reload (opening the detail drawer asks
    # only for `selected`) does no dashboard work at all.
    dashboard = nil
    result = -> { dashboard ||= AssessmentDashboard.new(company: Current.company, filters: filters).call }

    render inertia: {
      filters: filters.to_h,
      status_options: Status::CANONICAL.map { |value| { value: value, label: Status.label(value) } },
      assessments: -> { result.call.rows.map(&:to_list) },
      counts: -> { result.call.counts },
      pagination: -> {
        { page: result.call.page, pages: result.call.pages, total: result.call.total, per_page: AssessmentDashboard::PER_PAGE }
      },
      selected: -> { selected_detail }
    }
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
    source = explicit_filters? ? params : cookie_preferences.remembered_filters.merge(page: params[:page])
    AssessmentDashboard::Filters.from_params(source)
  end

  def remember(filters)
    preset = filters.preset == "custom" ? "all" : filters.preset
    cookie_preferences.remember_filters(status: filters.status, preset: preset)
  end

  def selected_detail
    return if params[:selected].blank?

    AssessmentRow.find(Current.company, params[:selected])&.to_detail
  end
end
