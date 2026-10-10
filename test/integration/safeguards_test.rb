require "test_helper"

class SafeguardsPageTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get safeguards_path

    assert_redirected_to new_session_path
  end

  test "renders the cards and the log example" do
    sign_in_as(create_admin(company: create_company))

    get safeguards_path

    assert_response :success
    assert_inertia_component "safeguards/index"
    props = inertia.props.with_indifferent_access
    assert_equal 5, props[:cards].size
    assert_match(/\[FILTERED\]/, props[:log_example][:after])
  end
end
