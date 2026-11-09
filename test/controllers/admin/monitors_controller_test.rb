require "test_helper"

class Admin::MonitorsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index and show" do
    get admin_monitors_path
    assert_response :success
    assert_select "td", text: "https://api.example.com/health"

    monitor = uptime_monitors(:website)
    monitor.record_check!(up_result)
    get admin_monitor_path(monitor)
    assert_response :success
    assert_select "table tbody tr", 1
  end

  test "create" do
    assert_difference -> { UptimeMonitor.count } => 1 do
      post admin_monitors_path, params: { uptime_monitor: { name: "Shop", url: "https://shop.example.com", interval_seconds: 120,
                                                            timeout_seconds: 5, expected_status_min: 200, expected_status_max: 299,
                                                            keyword: "Add to cart", failure_threshold: 3, active: "1" } }
    end

    monitor = UptimeMonitor.find_by!(name: "Shop")
    assert_redirected_to admin_monitor_path(monitor)
    assert_equal [ 120, 5, 200..299, "Add to cart", 3 ],
                 [ monitor.interval_seconds, monitor.timeout_seconds, monitor.expected_statuses, monitor.keyword, monitor.failure_threshold ]
  end

  test "create refuses a private target (SSRF)" do
    assert_no_difference -> { UptimeMonitor.count } do
      post admin_monitors_path, params: { uptime_monitor: { name: "Metadata", url: "http://169.254.169.254/latest/meta-data/" } }
    end
    assert_response :unprocessable_entity
    assert_select ".flash-alert li", /is refused: 169\.254\.169\.254 resolves to 169\.254\.169\.254, a private or reserved address/
  end

  test "create accepts a private target when ALLOW_PRIVATE_TARGETS is on" do
    with_private_targets_allowed do
      post admin_monitors_path, params: { uptime_monitor: { name: "Router", url: "http://192.168.1.1/" } }
    end
    assert UptimeMonitor.exists?(name: "Router")
  end

  test "update and destroy" do
    monitor = uptime_monitors(:api)
    patch admin_monitor_path(monitor), params: { uptime_monitor: { name: "Public API", active: "0" } }
    assert_redirected_to admin_monitor_path(monitor)
    assert_equal "Public API", monitor.reload.name
    assert_not monitor.active?

    monitor.record_check!(up_result)
    assert_difference -> { UptimeMonitor.count } => -1, -> { Check.count } => -1 do
      delete admin_monitor_path(monitor)
    end
    assert_redirected_to admin_monitors_path
  end

  test "check now enqueues a check" do
    monitor = uptime_monitors(:website)
    assert_enqueued_with job: CheckMonitorJob, args: [ monitor ] do
      post check_admin_monitor_path(monitor)
    end
    assert_redirected_to admin_monitor_path(monitor)
  end
end
