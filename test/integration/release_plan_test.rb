require "test_helper"

class ReleasePlanPageTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin(company: create_company)
  end

  test "requires sign in" do
    get release_plan_path
    assert_redirected_to new_session_path

    get release_plan_normalize_path, params: { value: "comp" }
    assert_redirected_to new_session_path
  end

  test "renders the plan for a signed-in admin" do
    sign_in_as(@admin)

    get release_plan_path

    assert_response :success
    assert_inertia_component "release_plan/index"
    props = inertia.props.with_indifferent_access
    assert_equal 8, props[:steps].size
    assert_equal 3, props[:rollback].size
    assert_equal ReleasePlan::SAMPLES, props[:samples]
  end

  test "the tester endpoint runs a value through the real rules" do
    sign_in_as(@admin)

    get release_plan_normalize_path, params: { value: "comp" }

    body = response.parsed_body
    assert_equal "completed", body.dig("backfill", "status")
    assert_equal true, body.dig("save", "accepted")
    assert_equal "Accepted, stored as Completed", body.dig("save", "title")
  end

  test "the tester copes with missing, oversized and odd input" do
    sign_in_as(@admin)

    get release_plan_normalize_path
    assert_equal "pending", response.parsed_body.dig("backfill", "status")

    get release_plan_normalize_path, params: { value: "x" * 10_000 }
    assert_response :success
    assert_equal false, response.parsed_body.dig("save", "accepted")

    get release_plan_normalize_path, params: { value: { a: 1 } }
    assert_response :success
  end
end
