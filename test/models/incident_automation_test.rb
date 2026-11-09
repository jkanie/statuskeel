require "test_helper"

# Incidents open when a monitor reaches its failure threshold and resolve when it recovers.
class IncidentAutomationTest < ActiveSupport::TestCase
  setup do
    @monitor = uptime_monitors(:website) # failure threshold 2
  end

  test "1 failed check below the threshold opens nothing and keeps the monitor up" do
    assert_no_difference -> { Incident.count } do
      @monitor.record_check!(down_result)
    end
    assert @monitor.up?
    assert_equal 1, @monitor.consecutive_failures
  end

  test "reaching the threshold marks the monitor down and opens 1 automatic incident" do
    @monitor.record_check!(down_result)

    assert_difference -> { Incident.count } => 1, -> { IncidentUpdate.count } => 1 do
      @monitor.record_check!(down_result(error: "timed out after 10 s"))
    end

    assert @monitor.down?
    incident = @monitor.incidents.sole
    assert incident.automatic?
    assert incident.investigating?
    assert incident.impact_major?
    assert_equal "Website is down", incident.title
    assert_equal "Opened automatically after 2 failed checks in a row. Last error: timed out after 10 s.",
                 incident.updates.sole.body.to_plain_text
  end

  test "more failures after the threshold do not open more incidents" do
    3.times { @monitor.record_check!(down_result) }
    assert_equal 1, @monitor.incidents.count
    assert_equal 3, @monitor.consecutive_failures
  end

  test "a threshold of 3 needs 3 failures" do
    monitor = uptime_monitors(:api)
    2.times { monitor.record_check!(down_result) }
    assert monitor.incidents.none?
    monitor.record_check!(down_result)
    assert_equal 1, monitor.incidents.count
  end

  test "a passing check resolves the automatic incident with an automatic update" do
    2.times { @monitor.record_check!(down_result) }
    incident = @monitor.incidents.sole

    @monitor.record_check!(up_result(status: 200, ms: 95))

    assert @monitor.up?
    assert_equal 0, @monitor.consecutive_failures
    assert incident.reload.resolved?
    assert_not_nil incident.resolved_at
    assert_equal "Resolved automatically: Website responded with HTTP 200 in 95 ms.",
                 incident.updates.first.body.to_plain_text
  end

  test "recovery leaves incidents opened by hand alone" do
    manual = Incident.open!(title: "Payment provider issues", body: "Looking into it.", uptime_monitor: @monitor)
    @monitor.record_check!(up_result)
    assert manual.reload.investigating?
  end

  test "no automatic incident while one opened by hand is unresolved for the monitor" do
    Incident.open!(title: "Planned work", body: "Moving servers.", uptime_monitor: @monitor)
    2.times { @monitor.record_check!(down_result) }
    assert_equal 1, @monitor.incidents.count
  end

  test "an incident resolved by hand during an outage is not re-opened by later failures" do
    2.times { @monitor.record_check!(down_result) }
    @monitor.incidents.sole.post_update!(status: :resolved, body: "Known issue, closing.")

    @monitor.record_check!(down_result)
    assert_equal 1, @monitor.incidents.count
  end
end
