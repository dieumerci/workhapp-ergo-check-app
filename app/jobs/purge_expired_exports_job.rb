# Download links last 24 hours; after that the generated file is deleted too,
# so exported data does not linger in storage.
class PurgeExpiredExportsJob < ApplicationJob
  queue_as :default

  def perform
    AssessmentExport.where(state: "ready").where(expires_at: ...Time.current).where.associated(:file_attachment).find_each do |export|
      export.file.purge
    end
  end
end
