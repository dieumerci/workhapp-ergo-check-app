module AssessmentExports
  # Raised when building a file takes longer than EXPORT_MAX_SECONDS, so one
  # huge export cannot hold a worker forever. The user is told to narrow the range.
  class TimeBudgetExceeded < StandardError; end
end
