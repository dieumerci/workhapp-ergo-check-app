ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"

# Build the Vite bundle once, here, before the parallel workers fork. Left to
# autoBuild, every worker races to build it on a cold cache and they delete
# each other's output (ENOTEMPTY). A no-op when the bundle is already fresh.
ViteRuby.commands.build

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

    # Runs the block with the log at DEBUG (so SQL and parameters are written)
    # and returns everything that was logged.
    def captured_log
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io)
      logger.level = Logger::DEBUG
      previous = [ Rails.logger, ActionController::Base.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger ]
      Rails.logger = ActionController::Base.logger = ActiveRecord::Base.logger = ActiveJob::Base.logger = logger
      yield
      io.string
    ensure
      Rails.logger, ActionController::Base.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger = previous
    end

    SECTION_KEYS = %w[workstation_setup posture_movement breaks_recovery discomfort_reported].freeze

    def sections_json(*values)
      { "section_scores" => SECTION_KEYS.zip(values).to_h }
    end

    # Inserts a row the way years of legacy data look: no validations, so the
    # status can be "comp", "", nil, "on hold" and so on.
    def create_legacy_assessment(company:, status:, employee: nil, created_at: Time.current, responses: nil)
      employee ||= create_employee(company: company)
      id = Assessment.insert_all!(
        [ { company_id: company.id, employee_id: employee.id, employee_email: employee.email, status: status,
            responses_json: responses, created_at: created_at, updated_at: created_at } ],
        returning: %w[id]
      ).first["id"]
      Assessment.find(id)
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
