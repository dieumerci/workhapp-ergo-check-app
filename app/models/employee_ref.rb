# A one-way, per-company reference for an employee, e.g. "emp_a41f9c02".
#
# It lets an admin join exported rows back to people they can already see in
# the dashboard, without the export ever carrying a name or an e-mail address.
# It is an HMAC of the company and employee ids under a server-side secret, so
# it cannot be reversed or recomputed without the secret, is stable between
# exports, and differs between companies.
module EmployeeRef
  PREFIX = "emp_".freeze
  LENGTH = 8

  module_function

  def for(company_id:, employee_id:)
    digest = OpenSSL::HMAC.hexdigest("SHA256", key, "#{company_id}:#{employee_id}")
    "#{PREFIX}#{digest[0, LENGTH]}"
  end

  def key
    Rails.application.key_generator.generate_key("ergocheck employee ref")
  end
end
