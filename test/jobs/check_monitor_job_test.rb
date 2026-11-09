require "test_helper"

class CheckMonitorJobTest < ActiveJob::TestCase
  test "checks the URL and records the result" do
    monitor = uptime_monitors(:api)
    stub_request(:get, "https://api.example.com/health").to_return(status: 200, body: '{"status":"ok"}')

    assert_difference -> { monitor.checks.count } => 1 do
      CheckMonitorJob.perform_now(monitor)
    end
    assert monitor.reload.up?
    assert monitor.checks.recent.first.up?
  end

  test "2 failing runs open an incident and e-mail subscribers" do
    monitor = uptime_monitors(:website)
    stub_request(:get, "https://example.com/").to_return(status: 500)

    CheckMonitorJob.perform_now(monitor)
    assert_enqueued_jobs 1, only: NotifySubscribersJob do
      CheckMonitorJob.perform_now(monitor)
    end
    assert monitor.reload.down?
    assert_equal "Website is down", monitor.incidents.sole.title
  end

  test "skips paused monitors" do
    assert_no_difference -> { Check.count } do
      CheckMonitorJob.perform_now(uptime_monitors(:paused))
    end
  end

  test "updates the monitor row on the public page" do
    monitor = uptime_monitors(:api)
    stub_request(:get, "https://api.example.com/health").to_return(status: 200, body: "ok")

    broadcasts = capture_turbo_stream_broadcasts(StatusPage::STREAM) { CheckMonitorJob.perform_now(monitor) }
    assert_equal [ "overall", "uptime_monitor_#{monitor.id}" ], broadcasts.map { |stream| stream["target"] }
  end
end
