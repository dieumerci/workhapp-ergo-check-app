# OpenAI's Chat Completions API with function calling. Model: ASSISTANT_MODEL.
class Assistant::Clients::OpenAi
  URL = "https://api.openai.com/v1/chat/completions".freeze
  DEFAULT_MODEL = "gpt-4o-mini".freeze

  def initialize(key, transport: nil)
    @key = key
    @transport = transport
  end

  def complete(system:, message:, tools:, context: nil)
    body = {
      model: ENV.fetch("ASSISTANT_MODEL", DEFAULT_MODEL), max_completion_tokens: 400,
      messages: [ { role: "system", content: system }, { role: "user", content: message } ],
      tools: tools.map { |tool| { type: "function", function: { name: tool[:name], description: tool[:description], parameters: tool[:schema] } } },
      tool_choice: "auto"
    }
    reply = Assistant::Clients::Http.post_json(URL, headers: { "Authorization" => "Bearer #{@key}" }, body: body, transport: @transport)
    parse(reply)
  end

  private

  def parse(reply)
    message = reply.dig("choices", 0, "message") || {}
    calls = Array(message["tool_calls"]).filter_map do |call|
      Assistant::Call.new(call.dig("function", "name"), JSON.parse(call.dig("function", "arguments").to_s))
    rescue JSON::ParserError
      nil
    end
    Assistant::Response.new(message["content"].to_s, calls)
  end
end
