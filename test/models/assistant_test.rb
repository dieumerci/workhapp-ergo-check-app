require "test_helper"

class AssistantTest < ActiveSupport::TestCase
  NONE = { "ASSISTANT_PROVIDER" => nil, "ANTHROPIC_API_KEY" => nil, "OPENAI_API_KEY" => nil }.freeze

  test "with nothing configured the assistant does not exist" do
    with_env(NONE) do
      assert_not Assistant.enabled?
      assert_nil Assistant.provider
      assert_equal({ enabled: false }, Assistant.public_info)
      assert_raises(Assistant::Unavailable) { Assistant.client }
    end
  end

  test "a key turns it on, and says who sees the question" do
    with_env(NONE.merge("ANTHROPIC_API_KEY" => "sk-ant-test")) do
      assert_equal "anthropic", Assistant.provider
      assert_equal({ enabled: true, provider: "Anthropic", offline: false }, Assistant.public_info)
      assert_instance_of Assistant::Clients::Anthropic, Assistant.client
    end
    with_env(NONE.merge("OPENAI_API_KEY" => "sk-test")) do
      assert_equal "openai", Assistant.provider
      assert_equal "OpenAI", Assistant.public_info[:provider]
      assert_instance_of Assistant::Clients::OpenAi, Assistant.client
    end
  end

  test "when both keys are set Anthropic is the default and ASSISTANT_PROVIDER can choose" do
    both = NONE.merge("ANTHROPIC_API_KEY" => "a", "OPENAI_API_KEY" => "o")
    with_env(both) { assert_equal "anthropic", Assistant.provider }
    with_env(both.merge("ASSISTANT_PROVIDER" => "openai")) { assert_equal "openai", Assistant.provider }
    with_env(both.merge("ASSISTANT_PROVIDER" => "OpenAI ")) { assert_equal "openai", Assistant.provider }
  end

  test "choosing a provider without its key falls back to what is configured, never to nothing it cannot call" do
    with_env(NONE.merge("ASSISTANT_PROVIDER" => "openai", "ANTHROPIC_API_KEY" => "a")) { assert_equal "anthropic", Assistant.provider }
    with_env(NONE.merge("ASSISTANT_PROVIDER" => "openai")) { assert_nil Assistant.provider }
  end

  test "the offline rules mode needs no key and says it is offline" do
    with_env(NONE.merge("ASSISTANT_PROVIDER" => "rules")) do
      assert Assistant.enabled?
      assert_equal({ enabled: true, provider: "Offline rules", offline: true }, Assistant.public_info)
      assert_instance_of Assistant::Clients::Rules, Assistant.client
    end
  end

  test "blank keys count as no key" do
    with_env(NONE.merge("ANTHROPIC_API_KEY" => "   ", "OPENAI_API_KEY" => "")) { assert_not Assistant.enabled? }
  end
end
