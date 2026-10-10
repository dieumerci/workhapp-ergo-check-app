ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Tests create their own data through these helpers instead of fixtures so
    # every test states exactly the tenants and rows it depends on.
    parallelize(workers: :number_of_processors)

    def create_company(name: "Northwind Logistics")
      Company.create!(name: name)
    end

    def create_employee(company:, name: "Amara Okafor", department: "Warehouse", email: "amara@example.com")
      Employee.create!(company: company, name: name, department: department, email: email)
    end

    def create_assessment(company:, employee: nil, **attrs)
      employee ||= create_employee(company: company)
      Assessment.create!({ company: company, employee: employee }.merge(attrs))
    end
  end
end
