# Content of the "Safeguards" page. The request-log example is not typed in:
# the "after" line is produced by the application's real parameter filter, so
# the page shows what the logs actually contain.
module Safeguards
  Card = Struct.new(:task, :title, :points, keyword_init: true)

  # What the inherited app logged for an export request: every parameter, raw.
  LEGACY_PARAMS = {
    "company_id" => "42",
    "employee_email" => "amara@example.com",
    "responses_json" => "{\"q7\":\"lower back pain…\"}"
  }.freeze

  # What a request to this app can carry. company_id is not accepted at all.
  CURRENT_PARAMS = {
    "from" => "2026-09-01",
    "to" => "2026-09-30",
    "status" => "completed",
    "employee_email" => "amara@example.com",
    "responses_json" => "{\"q7\":\"lower back pain…\"}"
  }.freeze

  module_function

  def cards
    [
      Card.new(task: "Task 1 · Export", title: "One company, always", points: [
        "The company comes from the signed-in admin's account, never from the request.",
        "Only two filters are accepted: date range and status. Anything else is ignored.",
        "Built in the background, so large exports never tie up a web request.",
        "Employees appear as a one-way reference. Names, emails, free text and raw responses are left out."
      ]),
      Card.new(task: "Task 2 · Dashboard", title: "Faster on large data", points: [
        "Ten rows per page, fetched from the server, never the whole table.",
        "Two indexes back the page: company and newest first, and company and status.",
        "Only the columns shown are loaded. No raw responses.",
        "Measured on a 300,000-row company: the old page took 94.5 s and 300,001 queries, this one about 23 ms and 2 queries (benchmarks/)."
      ]),
      Card.new(task: "Task 2 · Score", title: "Always present, always correct", points: [
        "The score is the rounded average of the four section scores.",
        "Shown for completed, follow-up and archived assessments.",
        "Pending and in-progress assessments say \"Not scored yet\" instead of showing a blank or a wrong number.",
        "A missing or unreadable section means no score, never a partial average."
      ]),
      Card.new(task: "Task 3 · Status", title: "Five values only", points: [
        "The status control offers only the five standard statuses.",
        "The server maps known aliases and rejects anything else on create and update.",
        "History is backfilled later, following the release plan."
      ]),
      Card.new(task: "Access · Sign-in", title: "Signed in, and nothing more", points: [
        "Sign-in needs a one-time verification code and is rate limited.",
        "Sessions expire after 8 idle hours; pages are never cached by the browser.",
        "Only essential cookies are used unless you opt in to remembering dashboard filters.",
        "Nothing typed at sign-in is written to the logs."
      ])
    ]
  end

  def log_example
    { before: render_params(LEGACY_PARAMS), after: render_params(filter.filter(CURRENT_PARAMS)) }
  end

  def filter
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  # The way Rails writes it in the request log.
  def render_params(params)
    "Parameters: #{params.inspect}"
  end
end
