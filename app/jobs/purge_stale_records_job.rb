# Housekeeping for the server-side state added for sessions and CAPTCHAs: rows
# nobody can use any more are removed so the tables stay small.
class PurgeStaleRecordsJob < ApplicationJob
  queue_as :default

  def perform
    AdminSession.purge_idle
    CaptchaChallenge.purge_expired
  end
end
