require "test_helper"

class PruneChecksJobTest < ActiveJob::TestCase
  test "deletes checks and daily counts older than 90 days" do
    monitor = uptime_monitors(:website)
    now = Time.current
    old = monitor.checks.create!(up: true, checked_at: now - 91.days)
    recent = monitor.checks.create!(up: true, checked_at: now - 89.days)
    old_day = monitor.daily_uptimes.create!(date: (now - 91.days).to_date, checks_count: 1, up_count: 1)
    recent_day = monitor.daily_uptimes.create!(date: (now - 89.days).to_date, checks_count: 1, up_count: 1)

    PruneChecksJob.perform_now(now:)

    assert_not Check.exists?(old.id)
    assert Check.exists?(recent.id)
    assert_not DailyUptime.exists?(old_day.id)
    assert DailyUptime.exists?(recent_day.id)
  end

  test "deletes subscriptions that were not confirmed within 3 days" do
    stale = subscribers(:unconfirmed)
    stale.update_columns(created_at: 4.days.ago)
    fresh = Subscriber.create!(email_address: "fresh@example.com")

    PruneChecksJob.perform_now

    assert_not Subscriber.exists?(stale.id)
    assert Subscriber.exists?(fresh.id)
    assert Subscriber.exists?(subscribers(:confirmed).id)
  end
end
