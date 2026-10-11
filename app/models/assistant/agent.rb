# Runs one question through the configured client and turns the answer into
# something the page can apply. Single turn, no memory, no data access.
class Assistant::Agent
  MAX_MESSAGE = 300
  MAX_REPLY = 400
  DEPARTMENT_LIMIT = 50
  DEPARTMENT_FORMAT = /\A[\p{L}\p{N} &\/'’.\-]{1,40}\z/
  EARLIEST = Date.new(2000, 1, 1)

  class EmptyQuestion < StandardError; end

  Result = Struct.new(:reply, :filters, :export, keyword_init: true)

  def initialize(company:, client: Assistant.client, today: Date.current)
    @company = company
    @client = client
    @today = today
  end

  def call(raw)
    message = self.class.clean(raw)
    raise EmptyQuestion if message.empty?

    departments = departments_of_company
    response = @client.complete(
      system: system_prompt(departments), message: message, tools: Assistant::Tools::DEFINITIONS,
      context: { departments: departments, today: @today }
    )
    build(response, departments)
  end

  def self.clean(raw)
    return "" unless raw.is_a?(String)

    raw.gsub(/[[:cntrl:]]/, " ").squish.first(MAX_MESSAGE)
  end

  private

  # Department names are the company's own vocabulary, not personal data. They are
  # the only company data the model sees, and only if they look like a name.
  def departments_of_company
    @company.employees.where.not(department: [ nil, "" ]).distinct.order(:department).limit(DEPARTMENT_LIMIT).pluck(:department)
      .map { |name| name.to_s.strip }.select { |name| name.match?(DEPARTMENT_FORMAT) }
  end

  def system_prompt(departments)
    <<~PROMPT.strip
      You help a company admin use an assessments dashboard. You do one thing: turn their request into dashboard filters with the set_filters tool, or into a CSV export for them to review with the prepare_export tool (only when they ask to export or download).
      Today is #{@today.iso8601}. Work out relative dates ("last month", "in September", "this quarter") as YYYY-MM-DD from today.
      Statuses: #{Status::CANONICAL.map { |value| "#{value} (#{Status.label(value)})" }.join(', ')}.
      Departments: #{departments.empty? ? "(none)" : departments.join(', ')}. Use a department only if it is exactly one of these.
      You never see assessments, scores, employee names or e-mail addresses, and you must not guess them. If asked about a specific person, say that employee names are searched with the search box on the page.
      If the request is unclear, ask one short question instead of calling a tool. Reply in one or two plain sentences, no markdown.
    PROMPT
  end

  def build(response, departments)
    filters = nil
    export = nil
    Array(response.calls).each do |call|
      input = call.input.is_a?(Hash) ? call.input.stringify_keys : {}
      case call.name
      when "set_filters" then filters ||= filters_from(input, departments)
      when "prepare_export" then export ||= export_from(input)
      end
    end

    Result.new(reply: reply_text(response.text, filters, export), filters: filters, export: export)
  end

  def filters_from(input, departments)
    status = input["status"].to_s
    status = "all" unless Assistant::Tools::STATUS_VALUES.include?(status)
    from, to = range(input)
    department = departments.find { |name| name.casecmp?(input["department"].to_s.strip) }
    preset = from || to ? "custom" : preset_from(input)

    { status: status, preset: preset, from: from&.iso8601 || "", to: to&.iso8601 || "", q: department.to_s }
  end

  def export_from(input)
    status = input["status"].to_s
    status = "all" unless Assistant::Tools::STATUS_VALUES.include?(status)
    from, to = range(input)
    preset = preset_from(input)
    if from.nil? && to.nil? && %w[7 30 90].include?(preset)
      from = @today - preset.to_i
      to = @today
    end

    { status: status, from: from&.iso8601 || "", to: to&.iso8601 || "" }
  end

  def preset_from(input)
    preset = input["preset"].to_s
    Assistant::Tools::PRESETS.include?(preset) ? preset : "all"
  end

  # Two valid, sensible dates, in order, or fewer.
  def range(input)
    from = date(input["from"])
    to = date(input["to"])
    from, to = to, from if from && to && from > to
    [ from, to ]
  end

  def date(value)
    parsed = Date.iso8601(value.to_s)
    parsed if parsed >= EARLIEST && parsed <= @today + 366
  rescue Date::Error
    nil
  end

  def reply_text(text, filters, export)
    cleaned = text.to_s.gsub(/[[:cntrl:]]/, " ").squish.first(MAX_REPLY)
    return cleaned if cleaned.present?
    return "Done: I set the filters. Review them and undo if that is not what you meant." if filters
    return "Here is the export I prepared. Nothing is created until you confirm it." if export

    "I can filter by status, date range and department, and prepare an export. Try “completed in the last 30 days” or “export September”."
  end
end
