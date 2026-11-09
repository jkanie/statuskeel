require "application_system_test_case"

class StatusPageLiveTest < ApplicationSystemTestCase
  test "the public page updates live when a monitor fails and recovers" do
    monitor = uptime_monitors(:website) # opens an incident at the 2nd failed check in a row
    monitor.record_check!(down_result)

    visit root_path
    assert_selector "#overall", text: "All systems operational"
    page.execute_script("window.sameDocument = true")

    # 1 check per step: the test cable adapter does not keep the order of messages sent at once.
    monitor.record_check!(down_result)

    assert_selector "#overall", text: "Partial outage"
    assert_selector "#uptime_monitor_#{monitor.id} .monitor-state", text: "Down"
    assert_selector "#incidents", text: "Website is down"

    monitor.record_check!(up_result)

    assert_selector "#overall", text: "All systems operational"
    assert_selector "#uptime_monitor_#{monitor.id} .monitor-state", text: "Operational"
    assert_no_selector "#incidents", text: "Website is down"
    assert_selector "#past-incidents", text: "Resolved automatically: Website responded with HTTP 200"
    assert page.evaluate_script("window.sameDocument"), "the page must not reload"
  end

  test "subscribing from the public page" do
    visit root_path
    fill_in "E-mail address", with: "visitor@example.com"
    click_on "Subscribe"

    assert_selector ".flash-notice", text: "Check your inbox to confirm the subscription."
    assert Subscriber.exists?(email_address: "visitor@example.com")
  end
end
