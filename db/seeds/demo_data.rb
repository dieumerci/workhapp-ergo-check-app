# Demo data for local development and the recorded walkthrough.
#
# Northwind Logistics reproduces the design prototype's dataset exactly: the
# same deterministic generator, so the dashboard shows 64 assessments split
# 6 pending / 10 in progress / 29 completed / 14 needs follow-up / 5 archived.
#
# On top of that a second tenant (Harbor & Pine Clinics) proves isolation, and
# a sprinkling of legacy mess ("comp", "done", nil, "", string scores, a
# missing section) shows how the dashboard and export cope with real history.
# Rows are inserted with insert_all so, like the real legacy table, they are
# allowed to hold values the validations would now reject.
class DemoData
  DEMO_PASSWORD = ENV.fetch("DEMO_ADMIN_PASSWORD", "ergocheck-demo-2026")
  SECTIONS = %w[workstation_setup posture_movement breaks_recovery discomfort_reported].freeze
  DEPARTMENTS = [ "Warehouse", "Dispatch", "Finance", "Customer Support", "Engineering", "People & Culture" ].freeze
  FIRST_NAMES = %w[Amara Liam Priya Daniel Sofia Kwame Hana Mateo Zoe Ibrahim Chloe Tariq Ingrid Noah Lucia Samir].freeze
  LAST_NAMES = %w[Okafor Nguyen Patel Becker Rossi Mensah Sato Alvarez Hughes Khan Dubois Haddad Larsen Carter Moreno Iyer].freeze
  FREE_TEXT = [
    "Lower back pain after long shifts.",
    "Wrist discomfort when typing for more than an hour.",
    "Monitor is too low and my neck gets stiff.",
    "No issues to report.",
    "Chair armrests do not adjust. Shoulders ache by afternoon."
  ].freeze
  STATUS_POOL = %w[completed completed completed completed pending in_progress in_progress needs_follow_up needs_follow_up archived].freeze

  # Same linear congruential generator as the design prototype.
  class Lcg
    def initialize(seed)
      @state = seed
    end

    def next_float
      @state = ((@state * 1_664_525) + 1_013_904_223) % 4_294_967_296
      @state / 4_294_967_296.0
    end

    def pick(count)
      (next_float * count).floor
    end
  end

  def self.run
    new.run
  end

  def run
    northwind = Company.find_or_create_by!(name: "Northwind Logistics")
    harbor = Company.find_or_create_by!(name: "Harbor & Pine Clinics")

    create_admin(northwind, "Maya Reyes", "maya.reyes@northwind.example")
    create_admin(harbor, "Jonas Weber", "jonas.weber@harborpine.example")

    seed_assessments(northwind, domain: "northwind.example", count: 64, generator_seed: 7, mess: true, fixed_ids: true)
    seed_assessments(harbor, domain: "harborpine.example", count: 24, generator_seed: 99, mess: false)
    ActiveRecord::Base.connection.reset_pk_sequence!("assessments")
    print_accounts
  end

  private

  def print_accounts
    puts <<~TEXT

      Demo company admins (sign in at http://localhost:3000):
        maya.reyes@northwind.example   Northwind Logistics (64 assessments)
        jonas.weber@harborpine.example Harbor & Pine Clinics (24 assessments)
      Password for both: #{DEMO_PASSWORD}
      (set DEMO_ADMIN_PASSWORD before seeding to choose your own)
    TEXT
  end

  def create_admin(company, name, email)
    Admin.find_or_create_by!(email: email) do |admin|
      admin.company = company
      admin.name = name
      admin.password = DEMO_PASSWORD
    end
  end

  def seed_assessments(company, domain:, count:, generator_seed:, mess:, fixed_ids: false)
    if company.assessments.exists?
      puts "#{company.name}: assessments already present, skipping"
      return
    end

    random = Lcg.new(generator_seed)
    mess_random = Lcg.new(2026)
    today = Date.current
    employees = {}
    rows = []

    count.times do |index|
      status = STATUS_POOL[random.pick(STATUS_POOL.size)]
      created = today - random.pick(110)
      sections = nil
      if %w[completed archived needs_follow_up].include?(status)
        base = status == "needs_follow_up" ? 34 + random.pick(28) : 58 + random.pick(38)
        sections = SECTIONS.map { [ 100, [ 15, base + random.pick(24) - 12 ].max ].min }
      end
      first = FIRST_NAMES[random.pick(16)]
      last = LAST_NAMES[random.pick(16)]
      department = DEPARTMENTS[random.pick(6)]

      email = "#{first}.#{last}.#{department.parameterize}@#{domain}".downcase
      employee = (employees["#{first} #{last}|#{department}"] ||= Employee.create!(
        company: company, name: "#{first} #{last}", department: department, email: email
      ))

      stored_status, sections_json = mess ? roughen(status, sections, mess_random, index) : [ status, sections ]
      timestamp = created.in_time_zone.change(hour: 9, min: random_minute(index))
      row = {
        company_id: company.id,
        employee_id: employee.id,
        employee_email: employee.email,
        status: stored_status,
        responses_json: responses_for(sections_json, mess_random),
        created_at: timestamp,
        updated_at: timestamp
      }
      # Northwind keeps the prototype's ids (A-10400, A-10407, ...).
      row[:id] = 10_400 + (index * 7) if fixed_ids
      rows << row
    end

    Assessment.insert_all!(rows)
    puts "#{company.name}: seeded #{rows.size} assessments for #{employees.size} employees"
  end

  # Mimics years of inconsistent data without changing which bucket a row ends
  # up in once it is classified.
  def roughen(status, sections, random, index)
    stored = status
    case status
    when "completed" then stored = [ "completed", "comp", "done", "complete", "completed" ][random.pick(5)]
    when "pending" then stored = [ "pending", nil, "", "n/a", "pending", "pending" ][random.pick(6)]
    when "needs_follow_up"
      # One status nobody can interpret. It lands in "needs follow-up" for a human to review.
      if index >= 30 && !@unknown_status_used
        stored = "on hold"
        @unknown_status_used = true
      end
    end
    sections = sections&.map { |value| random.next_float < 0.1 ? value.to_s : value }
    # One deliberately awkward row: an assessment with a missing section,
    # which cannot be scored honestly.
    sections = sections.dup.tap { |s| s[2] = nil } if index == 13 && sections
    [ stored, sections ]
  end

  def responses_for(sections, random)
    json = { "free_text" => { "q7" => FREE_TEXT[random.pick(FREE_TEXT.size)] } }
    json["section_scores"] = SECTIONS.zip(sections).to_h if sections
    json
  end

  def random_minute(index)
    (index * 7) % 60
  end
end
