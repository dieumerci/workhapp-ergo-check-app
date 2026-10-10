# Builds one export in the background so a large company never ties up a web
# request. The job id is the only argument (no filters, no personal data), and
# failures are recorded as a generic code: the exception's message can contain
# SQL or row values, so only its class name is logged.
class AssessmentExportJob < ApplicationJob
  queue_as :default
  self.log_arguments = false

  def perform(export_id)
    export = AssessmentExport.find_by(id: export_id)
    return unless export&.claim!

    AssessmentExports::Builder.new(export).call
  rescue AssessmentExports::TimeBudgetExceeded
    export&.mark_failed!("timeout")
    Rails.logger.warn("assessment export #{export_id} timed out")
  rescue StandardError => error
    export&.mark_failed!("error")
    Rails.logger.error("assessment export #{export_id} failed: #{error.class}")
  end
end
