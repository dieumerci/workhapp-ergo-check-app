require "test_helper"
require "minitest/mock"

class AssistantIntegrationTest < ActionDispatch::IntegrationTest
  RULES = { "ASSISTANT_PROVIDER" => "rules", "ANTHROPIC_API_KEY" => nil, "OPENAI_API_KEY" => nil }.freeze
  OFF = { "ASSISTANT_PROVIDER" => nil, "ANTHROPIC_API_KEY" => nil, "OPENAI_API_KEY" => nil }.freeze
  SECRET_QUESTION = "completed for Zephyrine Quillfeather".freeze

  setup do
    @company = create_company
    @admin = create_admin(company: @company)
    @other_company = create_company(name: "Harbor & Pine Clinics")
    create_employee(company: @company, name: "Amara Okafor", department: "Warehouse", email: "amara@example.com")
    create_employee(company: @other_company, name: "Zed Clinic", department: "Radiology", email: "zed@example.com")
  end

  def ask(message, **headers)
    post assistant_path, params: { message: message }, as: :json, headers: headers
  end

  test "with no provider configured the endpoint does not exist and the page does not offer it" do
    with_env(OFF) do
      sign_in_as(@admin)

      ask("completed")
      assert_response :not_found

      get assessments_path
      assert_equal({ "enabled" => false }, inertia.props.with_indifferent_access[:assistant].to_h)
    end
  end

  test "it needs a signed-in admin" do
    with_env(RULES) do
      ask("completed")
      assert_redirected_to new_session_path
    end
  end

  test "an enabled assistant is announced to the page, with who would see the question" do
    with_env(RULES) do
      sign_in_as(@admin)

      get assessments_path

      assert_equal({ "enabled" => true, "provider" => "Offline rules", "offline" => true }, inertia.props.with_indifferent_access[:assistant].to_h)
    end
  end

  test "a question comes back as filters the page can apply" do
    with_env(RULES) do
      sign_in_as(@admin)

      ask "completed in warehouse for the last 30 days"

      assert_response :success
      body = response.parsed_body
      assert_equal({ "status" => "completed", "preset" => "30", "from" => "", "to" => "", "q" => "Warehouse" }, body["filters"])
      assert_nil body["export"]
      assert_match(/Offline mode/, body["reply"])
    end
  end

  test "an export request is only a proposal: nothing is created" do
    with_env(RULES) do
      sign_in_as(@admin)

      assert_no_difference -> { AssessmentExport.count } do
        ask "export completed assessments from the last 30 days"
      end

      assert_response :success
      assert_equal "completed", response.parsed_body["export"]["status"]
      assert_nil response.parsed_body["filters"]
    end
  end

  test "it only ever knows this company's departments" do
    with_env(RULES) do
      sign_in_as(@admin)

      ask "radiology"
      assert_equal "", response.parsed_body.dig("filters", "q").to_s

      ask "warehouse"
      assert_equal "Warehouse", response.parsed_body.dig("filters", "q")
    end
  end

  test "an empty question is a polite 422" do
    with_env(RULES) do
      sign_in_as(@admin)

      ask "   "
      assert_response :unprocessable_entity
      assert_match(/Type a question/, response.parsed_body["error"])
    end
  end

  test "a provider that fails is a 503 with a friendly message, and the question is nowhere in it" do
    failing = Object.new
    failing.define_singleton_method(:complete) { |**| raise Assistant::Unavailable, "The assistant is busy right now. Try again in a moment." }
    with_env(RULES) do
      sign_in_as(@admin)

      Assistant.stub(:client, failing) { ask SECRET_QUESTION }

      assert_response :service_unavailable
      assert_match(/busy/, response.parsed_body["error"])
      assert_not_includes response.body, "Zephyrine"
    end
  end

  test "what is typed into the assistant never reaches the log" do
    with_env(RULES) do
      sign_in_as(@admin)

      log = captured_log { ask SECRET_QUESTION }

      assert_not_includes log, "Zephyrine"
      assert_not_includes log, "Quillfeather"
      assert_match(/"message"=>"\[FILTERED\]"/, log)
    end
  end

  test "failures are logged by class only" do
    failing = Object.new
    failing.define_singleton_method(:complete) { |**| raise Assistant::Unavailable, "boom #{SECRET_QUESTION}" }
    with_env(RULES) do
      sign_in_as(@admin)

      log = captured_log { Assistant.stub(:client, failing) { ask SECRET_QUESTION } }

      assert_match(/assistant unavailable: Assistant::Unavailable/, log)
      assert_not_includes log, "Zephyrine"
    end
  end

  test "questions are rate limited per admin" do
    with_env(RULES) do
      sign_in_as(@admin)

      20.times { ask "completed" }
      assert_response :success
      ask "completed"

      assert_response :too_many_requests
      assert_match(/a lot of questions/, response.parsed_body["error"])
    end
  end
end
