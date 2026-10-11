# The offline mode (ASSISTANT_PROVIDER=rules): no AI and no network. A handful of
# plain rules read the question for a status, a period, a month, a department and
# the word "export", and return the same tool calls a model would. It lets the
# assistant be tried, demonstrated and tested without a key, and says so.
class Assistant::Clients::Rules
  STATUS_WORDS = {
    "needs_follow_up" => /follow[- ]?ups?|needs? follow/,
    "in_progress" => /in[- ]progress|ongoing|under way|started/,
    "completed" => /complet|\bdone\b|finished/,
    "pending" => /pending|not started|waiting|to do/,
    "archived" => /archiv/
  }.freeze
  PRESET_WORDS = {
    "7" => /(last|past) (7|seven) days|last week|this week/,
    "30" => /(last|past) (30|thirty) days|last month|this month/,
    "90" => /(last|past) (90|ninety) days|last quarter|this quarter|three months|3 months/,
    "all" => /all time|ever\b|everything/
  }.freeze
  MONTHS = %w[january february march april may june july august september october november december].freeze
  NOTE = "Offline mode: I read your request with simple rules, no AI. ".freeze

  def complete(system:, message:, tools:, context:)
    text = message.downcase
    today = context.fetch(:today)
    input = {}

    status = STATUS_WORDS.find { |_, pattern| text.match?(pattern) }&.first
    input["status"] = status if status

    month = MONTHS.index { |name| text.match?(/\b#{name}\b/) }
    if month
      year = text[/\b(20\d\d)\b/, 1]&.to_i || (month + 1 > today.month ? today.year - 1 : today.year)
      first = Date.new(year, month + 1, 1)
      input["from"] = first.iso8601
      input["to"] = first.end_of_month.iso8601
    elsif (preset = PRESET_WORDS.find { |_, pattern| text.match?(pattern) }&.first)
      input["preset"] = preset
    end

    department = context.fetch(:departments).find { |name| text.include?(name.downcase) }
    input["department"] = department if department

    exporting = text.match?(/\bexport|download|csv\b/)
    calls = []
    calls << Assistant::Call.new("prepare_export", input.slice("status", "preset", "from", "to")) if exporting
    calls << Assistant::Call.new("set_filters", input) if !exporting && input.any?

    Assistant::Response.new(reply(calls), calls)
  end

  private

  def reply(calls)
    return "#{NOTE}I could not tell what to filter. Try “completed in the last 30 days”, “needs follow-up in Finance” or “export September”." if calls.empty?

    "#{NOTE}Here is what I understood."
  end
end
