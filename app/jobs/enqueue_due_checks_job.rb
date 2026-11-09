# Runs every minute (config/recurring.yml) and enqueues a check for each monitor that is due.
class EnqueueDueChecksJob < ApplicationJob
  queue_as :default

  # Monitors due within this margin are checked now, so a 60 s monitor is not pushed to every 2nd run.
  GRACE = 5.seconds

  def perform(now: Time.current)
    monitors = UptimeMonitor.due(now + GRACE).to_a
    monitors.each { |monitor| monitor.update_columns(next_check_at: now + monitor.interval_seconds) }
    ActiveJob.perform_all_later(monitors.map { |monitor| CheckMonitorJob.new(monitor) })
  end
end
