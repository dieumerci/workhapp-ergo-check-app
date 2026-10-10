# Reproducible dashboard measurements (development only).
#
#   bin/rails perf:seed ROWS=100000     # one big tenant, realistic legacy mix
#   bin/rails perf:benchmark            # legacy-style page vs the current one
#   bin/rails perf:report               # several sizes in a row (SIZES=5000,25000,100000)
#   bin/rails perf:clean                # remove the benchmark tenant
#
# "Before" replays what the inherited page did: load every assessment of the
# company with every column (raw answers included), look the employee up one
# row at a time, score each row in Ruby, count statuses in Ruby, render it all.
# "After" is AssessmentDashboard: one grouped COUNT plus one page of ten rows.
require "benchmark"

module Perf
  COMPANY_NAME = "Benchmark Co (perf data)".freeze
  NOISE_PREFIX = "Benchmark Noise ".freeze
  NOISE_TENANTS = 20
  # The two indexes the dashboard ships with (see the migration).
  ORDERING_INDEX = "idx_assessments_company_created".freeze
  STATUS_INDEX = "idx_assessments_company_status_created".freeze
  INDEX_SETS = {
    none: [],
    ordering: [ ORDERING_INDEX ],
    both: [ ORDERING_INDEX, STATUS_INDEX ]
  }.freeze

  module_function

  def guard!
    abort "perf tasks are for development only" if Rails.env.production?
  end

  def company
    Company.find_by(name: COMPANY_NAME)
  end

  # One big tenant of +rows+ assessments, plus 3x as many spread over other
  # tenants, so the table looks like a real multi-tenant one: the big tenant is
  # a quarter of it and the planner has to find its rows among everyone's.
  def seed(rows)
    clean
    company = Company.create!(name: COMPANY_NAME)
    insert_tenant(company, rows)
    noise_rows = rows * 3 / NOISE_TENANTS
    NOISE_TENANTS.times { |index| insert_tenant(Company.create!(name: "#{NOISE_PREFIX}#{index + 1}"), noise_rows) }
    connection = ActiveRecord::Base.connection
    connection.execute("ANALYZE assessments")
    connection.execute("ANALYZE employees")
    company
  end

  def insert_tenant(company, rows)
    employee_count = [ rows / 25, 20 ].max
    connection = ActiveRecord::Base.connection

    connection.execute(<<~SQL)
      INSERT INTO employees (company_id, name, email, department, created_at, updated_at)
      SELECT #{company.id}, 'Employee ' || g, 'employee' || g || '@bench.example',
             (ARRAY['Warehouse','Dispatch','Finance','Support','Engineering','People'])[1 + g % 6], now(), now()
      FROM generate_series(1, #{employee_count}) g
    SQL
    base_id = connection.select_value("SELECT min(id) FROM employees WHERE company_id = #{company.id}")

    connection.execute(<<~SQL)
      INSERT INTO assessments (company_id, employee_id, employee_email, status, responses_json, created_at, updated_at)
      SELECT #{company.id},
             #{base_id} + (g % #{employee_count}),
             'employee' || ((g % #{employee_count}) + 1) || '@bench.example',
             (ARRAY['completed','completed','comp','done','complete','pending','','n/a',NULL,
                    'in_progress','in_progress','needs_follow_up','needs_follow_up','archived','on hold'])[1 + floor(random() * 15)::int],
             jsonb_build_object(
               'section_scores', jsonb_build_object(
                 'workstation_setup', 40 + floor(random() * 60)::int,
                 'posture_movement', 40 + floor(random() * 60)::int,
                 'breaks_recovery', 40 + floor(random() * 60)::int,
                 'discomfort_reported', 40 + floor(random() * 60)::int),
               'free_text', jsonb_build_object(
                 'q7', repeat('Lower back pain after long shifts. ', 6),
                 'q9', repeat('Chair armrests do not adjust. ', 4))),
             now() - (random() * interval '730 days'),
             now()
      FROM generate_series(1, #{rows}) g
    SQL
  end

  def clean
    Company.where("name = ? OR name LIKE ?", COMPANY_NAME, "#{NOISE_PREFIX}%").find_each do |existing|
      Assessment.where(company_id: existing.id).delete_all
      Employee.where(company_id: existing.id).delete_all
      existing.destroy
    end
  end

  # ---- what the inherited page did ------------------------------------

  def legacy_page(company, status: nil)
    scope = Assessment.where(company_id: company.id)
    scope = scope.where(status: status) if status
    records = scope.order(created_at: :desc).to_a # every row, every column
    rows = records.map do |assessment|
      sections = assessment.responses_json&.dig("section_scores")&.values
      score = sections && sections.all?(Numeric) ? (sections.sum / sections.size).round : nil
      { id: assessment.id, employee: assessment.employee.name, status: assessment.status, score: score }
    end
    counts = records.group_by(&:status).transform_values(&:size)
    [ rows, counts ]
  end

  def current_page(company, **params)
    result = AssessmentDashboard.new(company: company, filters: AssessmentDashboard::Filters.from_params(params)).call
    [ result.rows.map(&:to_list), result.counts ]
  end

  # ---- measuring --------------------------------------------------------

  def measure(runs: 1)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql].start_with?("EXPLAIN") }
    times = []
    objects = 0
    runs.times do
      queries = 0
      before = GC.stat(:total_allocated_objects)
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        times << Benchmark.realtime { yield }
      end
      objects = GC.stat(:total_allocated_objects) - before
    end
    { ms: (times.sort[times.size / 2] * 1000).round, queries: queries, objects: objects }
  end

  # Makes exactly +names+ present among the two dashboard indexes and runs the
  # block. The benchmark restores the shipped set (both) when it finishes.
  def with_indexes(names)
    connection = ActiveRecord::Base.connection
    { ORDERING_INDEX => [ %i[company_id created_at id], { created_at: :desc, id: :desc } ],
      STATUS_INDEX => [ %i[company_id status created_at], { created_at: :desc } ] }.each do |name, (columns, order)|
      exists = connection.index_name_exists?(:assessments, name)
      if names.include?(name) && !exists
        connection.add_index :assessments, columns, order: order, name: name, algorithm: :concurrently
      elsif !names.include?(name) && exists
        connection.remove_index :assessments, name: name, algorithm: :concurrently
      end
    end
    connection.execute("VACUUM (ANALYZE) assessments") # fresh visibility map for index-only scans
    yield
  end

  def benchmark(company, legacy_runs: 1)
    results = {}
    results[:before_default] = measure(runs: legacy_runs) { legacy_page(company) }
    results[:before_completed] = measure(runs: legacy_runs) { legacy_page(company, status: "completed") }
    INDEX_SETS.each do |set, names|
      with_indexes(names) do
        results[:"#{set}_default"] = measure(runs: 5) { current_page(company) }
        results[:"#{set}_completed"] = measure(runs: 5) { current_page(company, status: "completed") }
        results[:"#{set}_recent"] = measure(runs: 5) { current_page(company, status: "all", preset: "90") }
      end
    end
    with_indexes(INDEX_SETS.fetch(:both)) { } # leave the shipped index set in place
    results
  end

  def print_results(rows, results)
    format = "%-40s %10s %9s %12s"
    puts format(format, "scenario (#{rows} rows)", "time ms", "queries", "objects")
    puts "-" * 74
    puts format(format, "before: default view", results[:before_default][:ms], results[:before_default][:queries], results[:before_default][:objects])
    puts format(format, "before: status=completed", results[:before_completed][:ms], results[:before_completed][:queries], results[:before_completed][:objects])
    { none: "after, no new index", ordering: "after, ordering index only", both: "after, both indexes (shipped)" }.each do |set, label|
      { default: "default view", completed: "status=completed", recent: "last 90 days" }.each do |scenario, name|
        result = results.fetch(:"#{set}_#{scenario}")
        puts format(format, "#{label}: #{name}", result[:ms], result[:queries], result[:objects])
      end
    end
  end

  # EXPLAIN ANALYZE for the SQL the current page really issues.
  def explain(company, **params)
    captured = []
    capture = lambda do |*, payload|
      next unless payload[:sql].include?('FROM "assessments"') && payload[:name] != "SCHEMA" && !payload[:sql].start_with?("EXPLAIN")

      binds = payload[:type_casted_binds]
      binds = binds.call if binds.respond_to?(:call)
      captured << [ payload[:sql], binds ]
    end
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") { current_page(company, **params) }

    captured.map do |sql, binds|
      plan = ActiveRecord::Base.connection.exec_query("EXPLAIN (ANALYZE, BUFFERS) #{sql}", "EXPLAIN", binds).rows.flatten
      [ sql, plan ]
    end
  end
end

namespace :perf do
  desc "Create one large tenant of ROWS assessments (default 100000)"
  task seed: :environment do
    Perf.guard!
    rows = ENV.fetch("ROWS", "100000").to_i
    elapsed = Benchmark.realtime { Perf.seed(rows) }
    puts "seeded #{rows} assessments in #{elapsed.round(1)}s"
  end

  desc "Compare the legacy-style page with the current one on the seeded tenant"
  task benchmark: :environment do
    Perf.guard!
    company = Perf.company or abort "run `bin/rails perf:seed ROWS=...` first"
    rows = Assessment.where(company_id: company.id).count
    Perf.print_results(rows, Perf.benchmark(company))
  end

  desc "Seed and benchmark several sizes (SIZES=5000,25000,100000)"
  task report: :environment do
    Perf.guard!
    ENV.fetch("SIZES", "5000,25000,100000").split(",").map(&:to_i).each do |rows|
      Perf.seed(rows)
      Perf.print_results(rows, Perf.benchmark(Perf.company))
      puts
    end
  end

  desc "EXPLAIN ANALYZE the SQL behind the default and status-filtered pages"
  task explain: :environment do
    Perf.guard!
    company = Perf.company or abort "run `bin/rails perf:seed ROWS=...` first"
    [ {}, { status: "completed" } ].each do |params|
      puts "== params: #{params.inspect}"
      Perf.explain(company, **params).each do |sql, plan|
        puts "-- #{sql.squish[0, 160]}"
        puts plan.first(14)
        puts
      end
    end
  end

  desc "Remove the benchmark tenant"
  task clean: :environment do
    Perf.guard!
    Perf.clean
    puts "benchmark tenant removed"
  end
end
