require "test_helper"

class Admin::IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "open an incident with a first update" do
    assert_difference -> { Incident.count } => 1, -> { IncidentUpdate.count } => 1 do
      post admin_incidents_path, params: { incident: { title: "Checkout fails", impact: "major", status: "identified",
                                                       uptime_monitor_id: uptime_monitors(:website).id,
                                                       body: "<div>A payment provider is down.</div>" } }
    end

    incident = Incident.last
    assert_redirected_to admin_incident_path(incident)
    assert incident.identified?
    assert incident.impact_major?
    assert_equal uptime_monitors(:website), incident.uptime_monitor
    assert_not incident.automatic?
    assert_equal "A payment provider is down.", incident.updates.sole.body.to_plain_text
  end

  test "a new incident needs a title and a first update" do
    assert_no_difference -> { Incident.count } do
      post admin_incidents_path, params: { incident: { title: "", impact: "minor", status: "investigating", body: "x" } }
    end
    assert_response :unprocessable_entity

    assert_no_difference -> { Incident.count } do
      post admin_incidents_path, params: { incident: { title: "Checkout fails", impact: "minor", status: "investigating", body: "" } }
    end
    assert_response :unprocessable_entity
    assert_select ".flash-alert li", "The first update needs a message"
  end

  test "post updates through to resolved" do
    incident = Incident.open!(title: "Checkout fails", body: "Looking.")

    post admin_incident_updates_path(incident), params: { incident_update: { status: "resolved", body: "Provider is back." } }

    assert_redirected_to admin_incident_path(incident)
    assert incident.reload.resolved?
    assert_equal "Provider is back.", incident.updates.first.body.to_plain_text
  end

  test "an empty update is refused" do
    incident = Incident.open!(title: "Checkout fails", body: "Looking.")
    post admin_incident_updates_path(incident), params: { incident_update: { status: "monitoring", body: "" } }
    assert_response :unprocessable_entity
    assert incident.reload.investigating?
  end

  test "index, show, edit, update and destroy" do
    incident = Incident.open!(title: "Checkout fails", body: "Looking.")

    get admin_incidents_path
    assert_select "a", "Checkout fails"
    get admin_incident_path(incident)
    assert_response :success
    get edit_admin_incident_path(incident)
    assert_response :success

    patch admin_incident_path(incident), params: { incident: { title: "Checkout fails for card payments", impact: "critical" } }
    assert_redirected_to admin_incident_path(incident)
    assert_equal "Checkout fails for card payments", incident.reload.title
    assert incident.impact_critical?

    assert_difference -> { Incident.count } => -1, -> { IncidentUpdate.count } => -1 do
      delete admin_incident_path(incident)
    end
  end

  test "keeps only the unresolved or the resolved incidents" do
    Incident.open!(title: "Checkout fails", body: "Looking.")
    Incident.open!(title: "Slow search", body: "Looking.").post_update!(status: :resolved, body: "Fixed.")

    get admin_incidents_path
    assert_select "tbody tr", 2
    assert_select "a[href=?]", admin_incidents_path(state: "unresolved"), text: "1 unresolved"
    assert_select "a[href=?]", admin_incidents_path(state: "resolved"), text: "1 resolved"
    assert_select "a", text: "Show all", count: 0

    get admin_incidents_path, params: { state: "unresolved" }
    assert_select "tbody tr", 1
    assert_select "tbody a", "Checkout fails"
    assert_select "p", text: /Showing only the unresolved ones\./
    assert_select "a[href=?]", admin_incidents_path, text: "Show all"

    get admin_incidents_path, params: { state: "resolved" }
    assert_select "tbody tr", 1
    assert_select "tbody a", "Slow search"

    Incident.resolved.destroy_all
    get admin_incidents_path, params: { state: "resolved" }
    assert_select "p", text: "No resolved incidents."

    get admin_incidents_path, params: { state: "destroy_all" }
    assert_select "tbody tr", 1
    assert_select "a", text: "Show all", count: 0
  end

  test "keeps only the incidents of 1 monitor" do
    website, api = uptime_monitors(:website), uptime_monitors(:api)
    Incident.open!(title: "Site down", body: "Looking.", uptime_monitor: website)
    Incident.open!(title: "Site slow", body: "Looking.", uptime_monitor: website).post_update!(status: :resolved, body: "Fixed.")
    Incident.open!(title: "API errors", body: "Looking.", uptime_monitor: api)
    Incident.open!(title: "Billing note", body: "Looking.")

    get admin_incidents_path
    assert_select "tbody tr", 4
    assert_select "tbody a[href=?]", admin_incidents_path(monitor: website.id), text: "Website", count: 2

    get admin_incidents_path, params: { monitor: website.id }
    assert_select "tbody tr", 2
    assert_select "p", text: /Showing only the incidents of Website\./
    assert_select "a[href=?]", admin_incidents_path(state: "unresolved", monitor: website.id)
    assert_select "a[href=?]", admin_incidents_path, text: "Show all"

    get admin_incidents_path, params: { monitor: website.id, state: "resolved" }
    assert_select "tbody tr", 1
    assert_select "tbody a", "Site slow"

    get admin_incidents_path, params: { monitor: uptime_monitors(:paused).id }
    assert_select "p", text: "No incidents of Old site."

    get admin_incidents_path, params: { monitor: 0 }
    assert_select "tbody tr", 4
    assert_select "a", text: "Show all", count: 0
  end

  test "keeps only 1 impact, with the other filters" do
    website = uptime_monitors(:website)
    Incident.open!(title: "Site down", body: "Looking.", impact: :major, uptime_monitor: website)
    Incident.open!(title: "Site slow", body: "Looking.", uptime_monitor: website)
    Incident.open!(title: "Card errors", body: "Looking.", impact: :major).post_update!(status: :resolved, body: "Fixed.")

    get admin_incidents_path
    assert_select "tbody a[href=?]", admin_incidents_path(impact: "major"), text: "Major", count: 2

    get admin_incidents_path, params: { impact: "major" }
    assert_select "tbody tr", 2
    assert_select "p", text: /Showing only the major impact ones\./
    assert_select "a[href=?]", admin_incidents_path(state: "resolved", impact: "major")
    assert_select "a[href=?]", admin_incidents_path, text: "Show all"

    get admin_incidents_path, params: { impact: "major", state: "unresolved", monitor: website.id }
    assert_select "tbody tr", 1
    assert_select "tbody a", "Site down"

    get admin_incidents_path, params: { impact: "critical" }
    assert_select "p", text: "No critical impact incidents."

    get admin_incidents_path, params: { impact: "huge" }
    assert_select "tbody tr", 3
    assert_select "a", text: "Show all", count: 0
  end
end
