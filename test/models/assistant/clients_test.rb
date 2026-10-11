require "test_helper"

class AssistantClientsTest < ActiveSupport::TestCase
  TOOLS = Assistant::Tools::DEFINITIONS
  SECRET_QUESTION = "completed for Priya Carter's back pain".freeze

  # A stand-in for the network: records the request, answers with a canned status and body.
  def transport(status: 200, body: "{}", record: [])
    ->(uri, headers, request_body) {
      record << { uri: uri.to_s, headers: headers, body: JSON.parse(request_body) }
      [ status, body.is_a?(String) ? body : JSON.generate(body) ]
    }
  end

  test "Anthropic: the request carries the key, the question, the tools and nothing else" do
    sent = []
    reply = { "content" => [ { "type" => "text", "text" => "Sure." }, { "type" => "tool_use", "name" => "set_filters", "input" => { "status" => "completed" } } ] }
    client = Assistant::Clients::Anthropic.new("sk-ant-secret", transport: transport(body: reply, record: sent))

    response = client.complete(system: "SYS", message: "completed", tools: TOOLS)

    request = sent.first
    assert_equal "https://api.anthropic.com/v1/messages", request[:uri]
    assert_equal "sk-ant-secret", request[:headers]["x-api-key"]
    assert_equal "2023-06-01", request[:headers]["anthropic-version"]
    assert_equal "SYS", request[:body]["system"]
    assert_equal [ { "role" => "user", "content" => "completed" } ], request[:body]["messages"]
    assert_equal %w[set_filters prepare_export], request[:body]["tools"].map { |tool| tool["name"] }
    assert_equal "object", request[:body]["tools"].first["input_schema"]["type"]
    assert_equal "Sure.", response.text
    assert_equal [ [ "set_filters", { "status" => "completed" } ] ], response.calls.map { |call| [ call.name, call.input ] }
  end

  test "OpenAI: function calling, with the arguments parsed from JSON" do
    sent = []
    reply = { "choices" => [ { "message" => { "content" => nil, "tool_calls" => [
      { "function" => { "name" => "prepare_export", "arguments" => "{\"preset\":\"30\"}" } },
      { "function" => { "name" => "set_filters", "arguments" => "{not json" } }
    ] } } ] }
    client = Assistant::Clients::OpenAi.new("sk-secret", transport: transport(body: reply, record: sent))

    response = client.complete(system: "SYS", message: "export last 30 days", tools: TOOLS)

    request = sent.first
    assert_equal "https://api.openai.com/v1/chat/completions", request[:uri]
    assert_equal "Bearer sk-secret", request[:headers]["Authorization"]
    assert_equal [ "system", "user" ], request[:body]["messages"].map { |message| message["role"] }
    assert_equal %w[set_filters prepare_export], request[:body]["tools"].map { |tool| tool["function"]["name"] }
    assert_equal [ [ "prepare_export", { "preset" => "30" } ] ], response.calls.map { |call| [ call.name, call.input ] }, "unparseable arguments are dropped"
    assert_equal "", response.text
  end

  test "ASSISTANT_MODEL chooses the model" do
    sent = []
    with_env("ASSISTANT_MODEL" => "my-model") do
      Assistant::Clients::Anthropic.new("k", transport: transport(record: sent)).complete(system: "s", message: "m", tools: TOOLS)
    end
    assert_equal "my-model", sent.first[:body]["model"]
  end

  test "failures become friendly errors that never carry the question, the key or the response body" do
    {
      401 => /key was rejected/, 403 => /not allowed/, 429 => /busy/, 500 => /unavailable right now \(500\)/
    }.each do |status, pattern|
      client = Assistant::Clients::Anthropic.new("sk-ant-secret", transport: transport(status: status, body: "{\"error\":\"#{SECRET_QUESTION}\"}"))
      error = assert_raises(Assistant::Unavailable) { client.complete(system: "s", message: SECRET_QUESTION, tools: TOOLS) }
      assert_match pattern, error.message
      assert_not_includes error.message, "Priya"
      assert_not_includes error.message, "sk-ant"
    end
  end

  test "an unreadable reply and a dead network are reported, not raised as crashes" do
    garbled = Assistant::Clients::OpenAi.new("k", transport: transport(body: "<html>nope</html>"))
    assert_raises(Assistant::Unavailable) { garbled.complete(system: "s", message: "m", tools: TOOLS) }

    [ Net::ReadTimeout, Net::OpenTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError ].each do |error|
      dead = Assistant::Clients::Anthropic.new("k", transport: ->(*) { raise error })
      raised = assert_raises(Assistant::Unavailable) { dead.complete(system: "s", message: "m", tools: TOOLS) }
      assert_match(/could not be reached/, raised.message)
    end
  end

  # ---- the offline rules --------------------------------------------------

  def rules(message, departments: [ "Finance", "Warehouse" ], today: Date.new(2026, 10, 12))
    Assistant::Clients::Rules.new.complete(system: "", message: message, tools: TOOLS, context: { departments: departments, today: today })
  end

  def inputs(response)
    response.calls.map { |call| [ call.name, call.input ] }
  end

  test "rules read a status, a period and a department" do
    assert_equal [ [ "set_filters", { "status" => "completed", "preset" => "30", "department" => "Warehouse" } ] ],
                 inputs(rules("Show completed assessments in warehouse from the last 30 days"))
    assert_equal [ [ "set_filters", { "status" => "needs_follow_up" } ] ], inputs(rules("who needs follow-up?"))
    assert_equal [ [ "set_filters", { "status" => "in_progress", "preset" => "7" } ] ], inputs(rules("in progress this week"))
    assert_equal [ [ "set_filters", { "status" => "pending" } ] ], inputs(rules("pending"))
    assert_equal [ [ "set_filters", { "status" => "archived", "preset" => "all" } ] ], inputs(rules("archived, all time"))
  end

  test "rules read a month, choosing the latest one that has already begun" do
    assert_equal [ [ "set_filters", { "from" => "2026-09-01", "to" => "2026-09-30" } ] ], inputs(rules("September"))
    assert_equal [ [ "set_filters", { "from" => "2025-12-01", "to" => "2025-12-31" } ] ], inputs(rules("december"))
    assert_equal [ [ "set_filters", { "from" => "2024-02-01", "to" => "2024-02-29" } ] ], inputs(rules("february 2024"))
  end

  test "rules turn an export request into a proposal, never into filters" do
    assert_equal [ [ "prepare_export", { "status" => "completed", "from" => "2026-09-01", "to" => "2026-09-30" } ] ],
                 inputs(rules("export completed September"))
    assert_equal [ [ "prepare_export", { "preset" => "90" } ] ], inputs(rules("download the last 90 days as csv"))
  end

  test "rules say when they understood nothing, and say they are rules" do
    response = rules("hello there")

    assert_empty response.calls
    assert_match(/Offline mode/, response.text)
    assert_match(/could not tell/, response.text)
    assert_match(/Offline mode/, rules("completed").text)
  end
end
