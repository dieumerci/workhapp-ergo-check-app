# Demo data for local development and the recorded walkthrough.
#
# Northwind Logistics reproduces the design prototype's dataset exactly: the
# same deterministic generator, so the dashboard shows 64 assessments split
# 6 pending / 10 in progress / 29 completed / 14 needs follow-up / 5 archived.
#
# On top of that two more tenants (Harbor & Pine Clinics, Summit Physio Group)
# prove isolation, Northwind has a second admin to show two people sharing a
# company, and a sprinkling of legacy mess ("comp", "done", nil, "", string
# scores, a missing section) shows how the dashboard and export cope with real
# history. Northwind and Harbor & Pine keep their original data so the numbers
# on the design (and in the tests) never move; Summit is extra.
# Rows are inserted with insert_all so, like the real legacy table, they are
# allowed to hold values the validations would now reject.
class DemoData
  DEFAULT_PASSWORD = "ergocheck-demo-2026".freeze
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

  # Read when needed, not when the file loads, so changing DEMO_ADMIN_PASSWORD and seeding
  # again takes effect. A blank value means "not set".
  def self.password
    ENV["DEMO_ADMIN_PASSWORD"].to_s.strip.then { |value| value.empty? ? DEFAULT_PASSWORD : value }
  end

  def self.run
    new.run
  end

  def run
    northwind = Company.find_or_create_by!(name: "Northwind Logistics")
    harbor = Company.find_or_create_by!(name: "Harbor & Pine Clinics")
    summit = Company.find_or_create_by!(name: "Summit Physio Group")

    create_admin(northwind, "Maya Reyes", "maya.reyes@northwind.example")
    create_admin(northwind, "Daniel Osei", "daniel.osei@northwind.example")
    create_admin(harbor, "Jonas Weber", "jonas.weber@harborpine.example")
    create_admin(summit, "Aisha Bello", "aisha.bello@summitphysio.example")

    seed_assessments(northwind, domain: "northwind.example", count: 64, generator_seed: 7, mess: true, fixed_ids: true)
    seed_assessments(harbor, domain: "harborpine.example", count: 24, generator_seed: 99, mess: false)
    seed_assessments(summit, domain: "summitphysio.example", count: 40, generator_seed: 311, mess: true)
    ActiveRecord::Base.connection.reset_pk_sequence!("assessments")
    print_accounts
  end

  private

  def print_accounts
    puts <<~TEXT

      Demo company admins (open the app, then sign in):
        maya.reyes@northwind.example       Northwind Logistics (64 assessments)
        daniel.osei@northwind.example      Northwind Logistics (same company, second admin)
        jonas.weber@harborpine.example     Harbor & Pine Clinics (24 assessments)
        aisha.bello@summitphysio.example   Summit Physio Group (40 assessments)
      Password for all of them: #{shown_password}
      (set DEMO_ADMIN_PASSWORD before seeding to choose your own)
    TEXT
  end

  # A demo account always ends up with the configured demo password. (It used to be set only
  # when the account was first created, so changing DEMO_ADMIN_PASSWORD later did nothing and
  # accounts created under another value could not be signed in to.)
  def create_admin(company, name, email)
    admin = Admin.find_or_initialize_by(email: email)
    admin.company ||= company
    admin.name = name if admin.new_record?
    admin.password = DemoData.password unless admin.persisted? && admin.authenticate(DemoData.password)
    admin.save!
    admin
  end

  # The password is a secret on a hosted copy: never write it to a log that others can read.
  def shown_password
    Rails.env.production? ? "the value of DEMO_ADMIN_PASSWORD" : DemoData.password
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
