# An optional assistant on the dashboard: "completed assessments in Warehouse from
# the last 30 days", "export September". It turns a sentence into the filters the
# page already has, and into an export the person still has to confirm.
#
# It is deliberately narrow, because the data is health data:
#   * Off unless a key is configured (ANTHROPIC_API_KEY or OPENAI_API_KEY), or the
#     offline rules mode is chosen (ASSISTANT_PROVIDER=rules). With nothing set it
#     does not exist: no button, and the endpoint answers 404.
#   * The model is sent the question, today's date, the allowed values and the
#     company's department names. Never an employee name, e-mail, answer, score or
#     assessment row. The key stays on the server.
#   * It acts through two tools, set_filters and prepare_export, whose output is
#     validated like any request. It cannot read data, write data, or create an
#     export: it proposes, the person confirms.
module Assistant
  class Unavailable < StandardError; end

  Call = Struct.new(:name, :input)
  Response = Struct.new(:text, :calls)

  LABELS = { "anthropic" => "Anthropic", "openai" => "OpenAI", "rules" => "Offline rules" }.freeze

  module_function

  # The provider to use, or nil when the assistant is off.
  def provider
    choice = ENV["ASSISTANT_PROVIDER"].to_s.strip.downcase
    return choice if choice == "rules"
    return choice if LABELS.key?(choice) && key_for(choice).present?

    return "anthropic" if key_for("anthropic").present?

    "openai" if key_for("openai").present?
  end

  def enabled?
    !provider.nil?
  end

  def client
    case provider
    when "anthropic" then Clients::Anthropic.new(key_for("anthropic"))
    when "openai" then Clients::OpenAi.new(key_for("openai"))
    when "rules" then Clients::Rules.new
    else raise Unavailable, "The assistant is not configured."
    end
  end

  # What the page is told: whether to show the assistant, and who sees the question.
  def public_info
    enabled? ? { enabled: true, provider: LABELS.fetch(provider), offline: provider == "rules" } : { enabled: false }
  end

  def key_for(name)
    ENV["#{name.upcase}_API_KEY"].to_s.strip.presence
  end
end
