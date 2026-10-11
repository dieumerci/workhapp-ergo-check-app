# Finds a company's assessments from what a person types into the search box:
#
#   "priya"            part of an employee's name        (case-insensitive)
#   "warehouse"        part of an employee's department
#   "priya warehouse"  every word has to match, in any order
#   "A-10708", "10708" an assessment code
#
# It only ever narrows a scope that is already the signed-in admin's company,
# and the employees it looks through are that company's too, so the search can
# not find (or reveal the existence of) another tenant's record.
#
# What was typed is a person's name more often than not, so it is treated like
# any other personal data: it goes to the database as a bind parameter, never
# inlined in the SQL text, and the bind is named "search_term", which the log
# filter masks (config/initializers/filter_parameter_logging.rb). It is never
# stored (not in the remembered-filters cookie either), and a search is not part
# of an export, which accepts exactly two filters.
class AssessmentSearch
  MAX_LENGTH = 64
  MAX_TERMS = 4
  BIND_NAME = "search_term".freeze
  CODE = /\A(?:a-?)?(\d{1,12})\z/i

  # What a person typed, made safe to carry in a URL and a bind: only text,
  # no control characters, one space between words, a sensible length.
  def self.clean(raw)
    return "" unless raw.is_a?(String)

    raw.gsub(/[[:cntrl:]]/, " ").squish.first(MAX_LENGTH)
  end

  attr_reader :text

  def initialize(company, raw)
    @company = company
    @text = self.class.clean(raw)
  end

  def present?
    text.present?
  end

  def terms
    text.split(" ").first(MAX_TERMS)
  end

  # +scope+ must already be restricted to the company (company.assessments...).
  def apply(scope)
    terms.reduce(scope) { |narrowed, term| narrowed.where(match_for(term)) }
  end

  private

  def match_for(term)
    employees = @company.employees.where(name_or_department(term)).select(:id)
    by_employee = Assessment.arel_table[:employee_id].in(employees.arel)
    code = term.match(CODE)
    code ? by_employee.or(Assessment.arel_table[:id].eq(code[1].to_i)) : by_employee
  end

  def name_or_department(term)
    table = Employee.arel_table
    table[:name].matches(bound(term)).or(table[:department].matches(bound(term)))
  end

  # "%term%" with LIKE's own wildcards escaped, as a bind rather than SQL text.
  def bound(term)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new(BIND_NAME, pattern, ActiveRecord::Type::String.new))
  end
end
