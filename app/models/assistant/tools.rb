# The only two things the assistant can do. Providers get these definitions in
# their own format; whatever comes back is validated by Assistant::Agent before
# it is used, so a model that ignores the schema cannot do more than a person
# typing the same values into the filters.
module Assistant::Tools
  STATUS_VALUES = (Status::CANONICAL + [ "all" ]).freeze
  PRESETS = %w[7 30 90 all].freeze

  PROPERTIES = {
    "status" => { "type" => "string", "enum" => STATUS_VALUES, "description" => "Assessment status. Use \"all\" for every status." },
    "preset" => { "type" => "string", "enum" => PRESETS, "description" => "The last 7, 30 or 90 days, or all time. For any other range, use from and to instead." },
    "from" => { "type" => "string", "description" => "First day of a date range, YYYY-MM-DD." },
    "to" => { "type" => "string", "description" => "Last day of a date range, YYYY-MM-DD." },
    "department" => { "type" => "string", "description" => "Exactly one of the department names given in the context. Never an employee name." }
  }.freeze

  DEFINITIONS = [
    {
      name: "set_filters",
      description: "Show the assessments the person asked about by setting the dashboard's filters (status, date range, department). Use it for questions like \"completed last month\" or \"who needs follow-up in Finance\".",
      schema: { "type" => "object", "properties" => PROPERTIES, "additionalProperties" => false }
    },
    {
      name: "prepare_export",
      description: "Prepare a CSV export for the person to review and confirm. Only when they ask to export or download. Takes a status and a date range; it never starts the export itself.",
      schema: { "type" => "object", "properties" => PROPERTIES.slice("status", "preset", "from", "to"), "additionalProperties" => false }
    }
  ].freeze
end
