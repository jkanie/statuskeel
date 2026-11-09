require "test_helper"

class StatusPageTest < ActiveSupport::TestCase
  test "all systems operational when every monitor is up and nothing is open" do
    page = StatusPage.new
    assert_equal "none", page.indicator
    assert_equal "All systems operational", page.description
    assert_equal %w[API Website], page.monitors.map(&:name), "paused monitors are hidden"
  end

  test "the worst open incident sets the level" do
    Incident.open!(title: "Slow search", body: "Looking.", impact: :minor)
    assert_equal "minor", StatusPage.new.indicator

    Incident.open!(title: "Checkout fails", body: "Looking.", impact: :critical)
    assert_equal "critical", StatusPage.new.indicator
  end

  test "resolved incidents do not count" do
    incident = Incident.open!(title: "Slow search", body: "Looking.", impact: :critical)
    incident.post_update!(status: :resolved, body: "Fixed.")

    page = StatusPage.new
    assert_equal "none", page.indicator
    assert_equal [ incident ], page.resolved_incidents
  end

  test "1 monitor down is a partial outage, all down is a major outage" do
    uptime_monitors(:website).update_columns(status: "down")
    assert_equal "Partial outage", StatusPage.new.description

    uptime_monitors(:api).update_columns(status: "down")
    assert_equal "Major outage", StatusPage.new.description
  end
end
