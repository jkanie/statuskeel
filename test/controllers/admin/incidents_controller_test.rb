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
end
