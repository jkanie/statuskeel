require "test_helper"

class EnqueueDueChecksJobTest < ActiveJob::TestCase
  test "enqueues a check for each due monitor and schedules its next check" do
    now = Time.current.change(usec: 0)
    website = uptime_monitors(:website)
    website.update_columns(next_check_at: now - 1.second)
    uptime_monitors(:api).update_columns(next_check_at: now + 1.minute)

    EnqueueDueChecksJob.perform_now(now:)

    assert_enqueued_jobs 1, only: CheckMonitorJob
    assert_enqueued_with job: CheckMonitorJob, args: [ website ]
    assert_equal now + 60.seconds, website.reload.next_check_at
  end

  test "includes monitors due within the grace period" do
    now = Time.current.change(usec: 0)
    uptime_monitors(:website).update_columns(next_check_at: now + 3.seconds)
    uptime_monitors(:api).update_columns(next_check_at: now + 1.minute)

    EnqueueDueChecksJob.perform_now(now:)
    assert_enqueued_jobs 1, only: CheckMonitorJob
  end

  test "a 2nd run in the same minute enqueues nothing more" do
    now = Time.current
    UptimeMonitor.update_all(next_check_at: nil)

    EnqueueDueChecksJob.perform_now(now:)
    EnqueueDueChecksJob.perform_now(now: now + 10.seconds)
    assert_enqueued_jobs 2, only: CheckMonitorJob # website and api, the paused monitor never runs
  end
end
