require "test_helper"

class EmployeeRefTest < ActiveSupport::TestCase
  test "has the emp_ prefix and twelve hex characters" do
    assert_match(/\Aemp_[0-9a-f]{12}\z/, EmployeeRef.for(company_id: 1, employee_id: 2))
  end

  test "is stable for the same employee" do
    assert_equal EmployeeRef.for(company_id: 1, employee_id: 2), EmployeeRef.for(company_id: 1, employee_id: 2)
  end

  test "differs between employees and between companies" do
    refs = [ [ 1, 2 ], [ 1, 3 ], [ 2, 2 ] ].map { |company, employee| EmployeeRef.for(company_id: company, employee_id: employee) }

    assert_equal 3, refs.uniq.size
  end

  test "is not derivable from the ids without the server secret" do
    ref = EmployeeRef.for(company_id: 1, employee_id: 2)
    naive = OpenSSL::Digest::SHA256.hexdigest("1:2")[0, 8]

    assert_not_equal "emp_#{naive}", ref
  end
end
