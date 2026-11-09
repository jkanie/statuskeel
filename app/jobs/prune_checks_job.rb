# Runs daily (config/recurring.yml). Deletes checks and daily counts older than the retention
# period (CHECK_RETENTION_DAYS, default 90) and subscriptions that were never confirmed.
class PruneChecksJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    cutoff = now - Rails.configuration.x.check_retention_days.days

    Check.older_than(cutoff).in_batches(of: 5_000).delete_all
    DailyUptime.older_than(cutoff.to_date).delete_all
    Subscriber.unconfirmed.where(created_at: ...(now - Subscriber::UNCONFIRMED_LIFETIME)).delete_all
  end
end
