# Everything the assessments page needs for one request, in two queries.
#
#   1. one grouped COUNT of the company's assessments in the date range, by raw
#      status. Legacy spellings are folded into the five canonical statuses in
#      Ruby (via Status.classify), so chip counts, the status filter and the
#      total are consistent even before history is backfilled.
#   2. one page of rows (10), with the employee joined in and only the columns
#      the page shows: no e-mail, no free text, no raw responses.
#
# The company is always passed in from the signed-in admin.
class AssessmentDashboard
  PER_PAGE = 10
  PRESET_DAYS = { "7" => 7, "30" => 30, "90" => 90 }.freeze

  # Normalised filter input. Anything unexpected falls back to "no filter".
  class Filters
    attr_reader :status, :preset, :from, :to, :page

    def self.from_params(params, today: Date.current)
      new(
        status: params[:status], preset: params[:preset], from: params[:from], to: params[:to],
        page: params[:page], today: today
      )
    end

    def initialize(status:, preset:, from:, to:, page:, today: Date.current)
      @status = Status::CANONICAL.include?(status.to_s) ? status.to_s : "all"
      @page = [ page.to_s.to_i, 1 ].max
      from_date = parse_date(from)
      to_date = parse_date(to)

      if from_date || to_date
        @preset = "custom"
        @from = from_date
        @to = to_date
      elsif PRESET_DAYS.key?(preset.to_s)
        @preset = preset.to_s
        @from = today - PRESET_DAYS.fetch(@preset)
        @to = today
      else
        @preset = "all"
      end
    end

    def date_range
      return if from.nil? && to.nil?

      (from&.in_time_zone&.beginning_of_day)..(to&.in_time_zone&.end_of_day)
    end

    # What the client needs to redisplay the controls.
    def to_h
      { status: status, preset: preset, from: from ? from.iso8601 : "", to: to ? to.iso8601 : "" }
    end

    private

    def parse_date(value)
      Date.iso8601(value) if value.is_a?(String) && value.present?
    rescue Date::Error
      nil
    end
  end

  Result = Struct.new(:rows, :counts, :total, :page, :pages, keyword_init: true)

  def initialize(company:, filters:)
    @company = company
    @filters = filters
  end

  def call
    raw_counts = dated_scope.group(:status).count
    counts = fold(raw_counts)
    total = counts.fetch(@filters.status == "all" ? "all" : @filters.status)
    pages = [ (total / PER_PAGE.to_f).ceil, 1 ].max
    page = [ @filters.page, pages ].min

    Result.new(rows: rows_for(page, raw_counts), counts: counts, total: total, page: page, pages: pages)
  end

  private

  def dated_scope
    scope = @company.assessments
    range = @filters.date_range
    range ? scope.where(created_at: range) : scope
  end

  # Folds raw legacy spellings into { "all" => 64, "pending" => 6, ... }.
  def fold(raw_counts)
    canonical = Status::CANONICAL.index_with(0)
    raw_counts.each { |raw, count| canonical[Status.classify(raw)] += count }
    canonical.merge("all" => canonical.values.sum)
  end

  def rows_for(page, raw_counts)
    scope = dated_scope
    scope = scope.where(status: raw_values_for(raw_counts)) unless @filters.status == "all"

    AssessmentRow.relation(scope)
      .order("assessments.created_at DESC", "assessments.id DESC")
      .limit(PER_PAGE)
      .offset((page - 1) * PER_PAGE)
      .map { |record| AssessmentRow.build(record) }
  end

  # The raw spellings present in this range that classify as the chosen status.
  def raw_values_for(raw_counts)
    raw_counts.keys.select { |raw| Status.classify(raw) == @filters.status }
  end
end
