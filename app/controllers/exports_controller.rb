# Company-scoped CSV exports.
#
# The company is always Current.company (from the session). Exactly two
# filters are read from the request, date range and status; every other
# parameter, including a company_id, is ignored.
class ExportsController < InertiaController
  include ActiveStorage::SetCurrent # lets the signed storage URL be generated for the download

  # Each limit needs its own `name:`. Rails builds the counter's key from the controller and the name, so two
  # unnamed limits in one controller would share a counter (previews would use up the export budget).
  rate_limit to: 10, within: 1.hour, only: %i[create retry], name: "create-retry", with: -> {
    redirect_back_or_to exports_path, alert: "Too many export requests. Please try again later."
  }

  # The preview runs a company-wide count on every call, so it is limited too.
  rate_limit to: 60, within: 1.minute, only: :preview, name: "preview", with: -> {
    render json: { count: 0, error: "Too many requests. Please wait a moment." }, status: :too_many_requests
  }

  def index
    render inertia: {}
  end

  # How many rows an export with these filters would contain.
  def preview
    export = build_export
    errors = input_errors(export, context: :preview)
    return render(json: { count: 0, error: errors.to_sentence }) if errors.any?

    render json: { count: scope_for(export).count, error: nil }
  end

  def create
    submit build_export
  end

  def retry
    source = Current.company.assessment_exports.find(params[:id])
    submit source.retry_for(Current.admin)
  end

  # Authorises, then hands the browser a one-minute signed storage link, so the
  # file never streams through the Rails process.
  def download
    export = Current.company.assessment_exports.find(params[:id])

    if export.downloadable?
      redirect_to export.download_url, allow_other_host: true
    elsif export.expired?
      redirect_to exports_path, alert: "That download has expired. Request a new export."
    else
      redirect_to exports_path, alert: "That export isn't ready yet."
    end
  end

  private

  def build_export
    Current.company.assessment_exports.new(
      admin: Current.admin,
      from_date: parse_date(params[:from]),
      to_date: parse_date(params[:to]),
      status_filter: params[:status].presence&.to_s || "all"
    )
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    @bad_date = true
    nil
  end

  def scope_for(export)
    AssessmentExports::Scope.call(Current.company, from: export.from_date, to: export.to_date, status: export.status_filter)
  end

  def submit(export)
    problems = problems_with(export)

    if problems.empty?
      export.save!
      AssessmentExportJob.perform_later(export.id)
      flash.inertia[:export_id] = export.id
      redirect_back_or_to exports_path
    else
      redirect_back_or_to exports_path, inertia: { errors: { export: problems } }
    end
  end

  # Problems with what was asked for, before looking at any data. The
  # :preview context skips create-only rules (the in-progress cap), which are
  # irrelevant to merely counting.
  def input_errors(export, context: nil)
    return [ "Dates must look like YYYY-MM-DD" ] if @bad_date

    export.valid?(context) ? [] : export.errors.full_messages
  end

  def problems_with(export)
    errors = input_errors(export)
    return errors if errors.any?
    return [ "No assessments match these filters." ] unless scope_for(export).exists?

    []
  end
end
