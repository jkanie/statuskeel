# Check counts per monitor per day (UTC), kept so the 90 day bars need 1 small query.
class DailyUptime < ApplicationRecord
  belongs_to :uptime_monitor

  scope :older_than, ->(date) { where(date: ...date) }

  def self.record!(monitor, date, up:)
    upsert({ uptime_monitor_id: monitor.id, date:, checks_count: 1, up_count: up ? 1 : 0 },
           unique_by: %i[uptime_monitor_id date],
           on_duplicate: Arel.sql("checks_count = daily_uptimes.checks_count + 1, " \
                                  "up_count = daily_uptimes.up_count + excluded.up_count"))
  end

  def percent
    UptimeHistory.percent(up_count, checks_count)
  end
end
