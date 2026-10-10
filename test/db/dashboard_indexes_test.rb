require "test_helper"

# The dashboard's speed depends on these two indexes (see the migration for the
# measurements). This stops a schema change from quietly removing or reshaping
# them.
class DashboardIndexesTest < ActiveSupport::TestCase
  def index(name)
    ActiveRecord::Base.connection.indexes(:assessments).find { |candidate| candidate.name == name }
  end

  test "rows come back newest first straight from an index" do
    ordering = index("idx_assessments_company_created")

    assert ordering, "expected idx_assessments_company_created"
    assert_equal %w[company_id created_at id], ordering.columns
    assert_equal({ "created_at" => :desc, "id" => :desc }, ordering.orders.stringify_keys)
  end

  test "status counts are answered from an index" do
    counts = index("idx_assessments_company_status_created")

    assert counts, "expected idx_assessments_company_status_created"
    assert_equal %w[company_id status created_at], counts.columns
    assert_equal({ "created_at" => :desc }, counts.orders.stringify_keys)
  end
end
