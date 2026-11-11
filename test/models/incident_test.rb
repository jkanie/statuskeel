require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  test "open! creates the incident with its first update" do
    incident = Incident.open!(title: "Login errors", body: "<p>Some users see errors.</p>", impact: :minor)

    assert incident.investigating?
    assert incident.impact_minor?
    assert_not_nil incident.started_at
    assert_equal "Some users see errors.", incident.updates.sole.body.to_plain_text
  end

  test "post_update! moves the incident to the update status and stamps resolved_at" do
    incident = Incident.open!(title: "Login errors", body: "Looking into it.")

    incident.post_update!(status: :identified, body: "Found a bad deploy.")
    assert incident.identified?
    assert_nil incident.resolved_at

    incident.post_update!(status: :resolved, body: "Rolled back.")
    assert incident.resolved?
    assert_not_nil incident.resolved_at
    assert_equal %w[resolved identified investigating], incident.updates.map(&:status)
  end

  test "duration runs from the start to the resolution" do
    incident = Incident.open!(title: "Slow", body: "Looking.")
    assert_nil incident.duration
    travel 95.minutes
    incident.post_update!(status: :resolved, body: "Fixed.")
    assert_in_delta 95.minutes.to_f, incident.duration, 1.0
  end

  test "re-opening clears resolved_at" do
    incident = Incident.open!(title: "Login errors", body: "Looking into it.")
    incident.post_update!(status: :resolved, body: "Fixed.")
    incident.post_update!(status: :monitoring, body: "Seen again, watching it.")
    assert_nil incident.resolved_at
  end

  test "rejects an unknown status or impact" do
    incident = Incident.new(title: "x", status: "sleeping", impact: "huge")
    assert_not incident.valid?
    assert incident.errors.of_kind?(:status, :inclusion)
    assert incident.errors.of_kind?(:impact, :inclusion)
  end

  test "an update needs a body" do
    incident = Incident.open!(title: "Login errors", body: "Looking into it.")
    assert_raises(ActiveRecord::RecordInvalid) { incident.post_update!(body: "") }
  end

  test "each update e-mails subscribers through a background job" do
    incident = Incident.open!(title: "Login errors", body: "Looking into it.")

    assert_enqueued_with(job: NotifySubscribersJob) do
      incident.post_update!(status: :identified, body: "Found it.")
    end
  end

  test "changes are broadcast to the public page" do
    assert_turbo_stream_broadcasts StatusPage::STREAM do
      Incident.open!(title: "Login errors", body: "Looking into it.")
    end

    broadcasts = capture_turbo_stream_broadcasts(StatusPage::STREAM) do
      Incident.open!(title: "Search is slow", body: "Looking into it.")
    end
    targets = broadcasts.map { |stream| stream["target"] }
    assert_includes targets, "overall"
    assert_includes targets, "incidents"
    assert_includes targets, "past-incidents"
    assert broadcasts.find { |stream| stream["target"] == "incidents" }.to_html.include?("Search is slow")
  end
end
