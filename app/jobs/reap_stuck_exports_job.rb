# Records exports whose worker or job disappeared (a killed dyno, a lost job) as
# failed, so the admin sees a Retry button instead of an eternal "Building file"
# and the per-company cap is released. The exports page already shows such rows
# as failed immediately; this makes it permanent.
class ReapStuckExportsJob < ApplicationJob
  queue_as :default

  def perform
    AssessmentExport.stalled.find_each { |export| export.mark_failed!("error") }
  end
end
