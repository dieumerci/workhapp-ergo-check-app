# Status normalization backfill. PLAN ONLY: designed and tested here, to be run
# by a person following the release plan (SOLUTION.md / db/release_plan/RUNBOOK.md).
#
#   bin/rails status:backfill:report            read-only audit, safe any time
#   bin/rails status:backfill:run CONFIRM=yes   batched update (needs step 3 done)
#   bin/rails status:backfill:rollback CONFIRM=yes
#
# Options: BATCH_SIZE=5000  PAUSE=0.2  FROM_ID=<id>   (production also needs BACKUP_TAKEN=yes)
namespace :status do
  namespace :backfill do
    def backfill
      StatusBackfill.new(batch_size: ENV.fetch("BATCH_SIZE", 5_000), pause: ENV.fetch("PAUSE", 0.2))
    end

    def guard_writes!(action)
      abort "Refusing to #{action}: re-run with CONFIRM=yes (this is the plan-only backfill)." unless ENV["CONFIRM"] == "yes"
      return unless Rails.env.production? && ENV["BACKUP_TAKEN"] != "yes"

      abort "Refusing to #{action} in production without BACKUP_TAKEN=yes. Capture and verify a backup first (release plan step 1)."
    end

    desc "Read-only audit of status values and what the backfill would do"
    task report: :environment do
      backfill.print_report
    end

    desc "Backfill historical statuses in batches (plan only; needs CONFIRM=yes)"
    task run: :environment do
      guard_writes!("run the backfill")
      updated = backfill.run!(from_id: ENV["FROM_ID"]&.to_i)
      puts "done: #{updated} rows updated"
    rescue StatusBackfill::NotReady => error
      abort error.message
    end

    desc "Restore original statuses from status_legacy (needs CONFIRM=yes)"
    task rollback: :environment do
      guard_writes!("roll the backfill back")
      restored = backfill.rollback!
      puts "done: #{restored} rows restored"
    rescue StatusBackfill::NotReady => error
      abort error.message
    end
  end
end
