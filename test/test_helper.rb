ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"

module ActiveSupport
  class TestCase
    # Tests create their own data through these helpers instead of fixtures so
    # every test states exactly the tenants and rows it depends on.
    parallelize(workers: :number_of_processors)

    def create_company(name: "Northwind Logistics")
      Company.create!(name: name)
    end

    TEST_PASSWORD = "ergocheck-test-pass".freeze

    def create_admin(company:, name: "Maya Reyes", email: "maya@example.com", password: TEST_PASSWORD)
      Admin.create!(company: company, name: name, email: email, password: password)
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

class ActionDispatch::IntegrationTest
  KNOWN_CAPTCHA = "48213".freeze
  DEFAULT_CAPTCHA_GENERATOR = Captcha.code_generator

  # Tests control the CAPTCHA answer through the generator seam, so the real
  # image rendering and digest verification are still exercised end to end.
  setup { Captcha.code_generator = -> { KNOWN_CAPTCHA } }
  teardown { Captcha.code_generator = DEFAULT_CAPTCHA_GENERATOR }

  # Loads a fresh challenge image (which stores its digest in the session),
  # then submits the sign-in form with the given answer.
  def attempt_sign_in(email:, password:, captcha: KNOWN_CAPTCHA)
    get captcha_path
    post session_path, params: { email: email, password: password, captcha: captcha }
  end

  def sign_in_as(admin, password: ActiveSupport::TestCase::TEST_PASSWORD)
    attempt_sign_in(email: admin.email, password: password)
  end
end
