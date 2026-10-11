# Anthropic's Messages API with tool use. Model: ASSISTANT_MODEL, default a fast, inexpensive one.
class Assistant::Clients::Anthropic
  URL = "https://api.anthropic.com/v1/messages".freeze
  DEFAULT_MODEL = "claude-haiku-5-5".freeze
  VERSION = "2023-06-01".freeze

  def initialize(key, transport: nil)
    @key = key
    @transport = transport
  end

  def complete(system:, message:, tools:, context: nil)
    body = {
      model: ENV.fetch("ASSISTANT_MODEL", DEFAULT_MODEL), max_tokens: 400, system: system,
      messages: [ { role: "user", content: message } ],
      tools: tools.map { |tool| { name: tool[:name], description: tool[:description], input_schema: tool[:schema] } },
      tool_choice: { type: "auto" }
    }
    reply = Assistant::Clients::Http.post_json(URL, headers: { "x-api-key" => @key, "anthropic-version" => VERSION }, body: body, transport: @transport)
    parse(reply)
  end

  private

  def parse(reply)
    blocks = Array(reply["content"])
    text = blocks.filter_map { |block| block["text"] if block["type"] == "text" }.join(" ")
    calls = blocks.filter_map { |block| Assistant::Call.new(block["name"], block["input"]) if block["type"] == "tool_use" }
    Assistant::Response.new(text, calls)
  end
end
