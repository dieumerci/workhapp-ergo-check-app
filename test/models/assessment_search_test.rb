require "test_helper"

class AssessmentSearchTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @other = create_company(name: "Harbor & Pine Clinics")
    @priya = create_employee(company: @company, name: "Priya Carter", department: "Finance", email: "priya@example.com")
    @tariq = create_employee(company: @company, name: "Tariq Rossi", department: "Customer Support", email: "tariq@example.com")
    @theirs = create_employee(company: @other, name: "Priya Carter", department: "Finance", email: "p2@example.com")
    @a1 = create_legacy_assessment(company: @company, employee: @priya, status: "completed")
    @a2 = create_legacy_assessment(company: @company, employee: @tariq, status: "pending")
    @a3 = create_legacy_assessment(company: @other, employee: @theirs, status: "completed")
  end

  def found(raw, company: @company)
    AssessmentSearch.new(company, raw).apply(company.assessments).order(:id).to_a
  end

  test "clean keeps only text a person could have typed, in a sensible length" do
    assert_equal "priya carter", AssessmentSearch.clean("  priya \n\t carter  ")
    assert_equal "ab", AssessmentSearch.clean("a\u0000b".sub("\u0000", ""))
    assert_equal AssessmentSearch::MAX_LENGTH, AssessmentSearch.clean("x" * 500).length
    assert_equal "", AssessmentSearch.clean(nil)
    assert_equal "", AssessmentSearch.clean([ "priya" ]), "an array parameter is not a search"
    assert_equal "", AssessmentSearch.clean({ "a" => "b" })
  end

  test "it matches part of a name, ignoring case" do
    assert_equal [ @a1 ], found("priya")
    assert_equal [ @a1 ], found("ARTER")
    assert_equal [ @a2 ], found("ross")
  end

  test "it matches the department" do
    assert_equal [ @a2 ], found("support")
    assert_equal [ @a1 ], found("fin")
  end

  test "every word has to match, in any order" do
    assert_equal [ @a1 ], found("carter priya")
    assert_equal [ @a1 ], found("priya finance")
    assert_empty found("priya support")
  end

  test "it matches an assessment code, with or without the prefix" do
    assert_equal [ @a1 ], found("A-#{@a1.id}")
    assert_equal [ @a1 ], found("a#{@a1.id}")
    assert_equal [ @a1 ], found(@a1.id.to_s)
    assert_empty found("A-999999999")
  end

  test "it can never find another company's record, even by name or code" do
    assert_equal [ @a1 ], found("priya"), "the other company's Priya Carter is not ours"
    assert_empty found("A-#{@a3.id}")
    assert_equal [ @a3 ], found("priya", company: @other)
  end

  test "LIKE wildcards typed by a person are plain characters" do
    assert_empty found("%")
    assert_empty found("_riya")
    assert_empty found("pri%a")
    create_employee(company: @company, name: "100% Effort", department: "Ops").then { |e| create_legacy_assessment(company: @company, employee: e, status: "pending") }
    assert_equal 1, found("100%").size
  end

  test "only the first few words count" do
    assert_equal [ @a1 ], found("priya carter finance a zzz qqq")
    assert_equal AssessmentSearch::MAX_TERMS, AssessmentSearch.new(@company, "a b c d e f").terms.size
  end

  test "a blank search narrows nothing" do
    assert_not AssessmentSearch.new(@company, "   ").present?
    assert_equal [ @a1, @a2 ], found("   ")
  end

  test "what was typed is sent to the database as a bind, not written into the SQL" do
    sql = []
    callback = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?("ILIKE") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { found("zephyrine") }

    assert_not_empty sql
    assert(sql.none? { |statement| statement.downcase.include?("zephyrine") })
    assert(sql.all? { |statement| statement.include?("ILIKE $") })
  end
end
