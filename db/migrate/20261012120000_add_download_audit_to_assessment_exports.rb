# Who exported health data, and how often was the file actually fetched? The
# export already records the requesting admin (admin_id); this adds the other
# half of an audit trail: how many times, and when last, the download link was
# used. A small, new table (not the large assessments table); a constant
# default is a metadata-only change in PostgreSQL 11+, so nothing is rewritten.
class AddDownloadAuditToAssessmentExports < ActiveRecord::Migration[8.1]
  def change
    add_column :assessment_exports, :download_count, :integer, default: 0, null: false
    add_column :assessment_exports, :last_downloaded_at, :datetime
  end
end
