require "test_helper"

class Admin::AuthenticationTest < ActionDispatch::IntegrationTest
  test "every admin screen redirects to sign-in when signed out" do
    [ admin_monitors_path, new_admin_monitor_path, admin_monitor_path(uptime_monitors(:website)),
      admin_incidents_path, new_admin_incident_path, admin_subscribers_path ].each do |path|
      get path
      assert_redirected_to new_session_path, "#{path} should need sign-in"
    end

    post admin_monitors_path, params: { uptime_monitor: { name: "x", url: "https://x.example.com" } }
    assert_redirected_to new_session_path
    assert_not UptimeMonitor.exists?(name: "x")
  end

  test "there is no sign-up route" do
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/users/new") }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/registration/new") }
  end

  test "signing in leads to the admin screens" do
    post session_path, params: { email_address: "one@example.com", password: "password" }
    follow_redirect!
    follow_redirect!
    assert_response :success
    assert_select "h1", "Monitors"
  end
end
