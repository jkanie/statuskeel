require "test_helper"

class StatusControllerTest < ActionDispatch::IntegrationTest
  test "the public page needs no sign-in and lists active monitors with 90 bars each" do
    get root_path

    assert_response :success
    assert_select "#overall", text: /All systems operational/
    assert_select "turbo-cable-stream-source", 1
    assert_select "#monitors .monitor", 2
    assert_select "#uptime_monitor_#{uptime_monitors(:website).id} .bar", 90
    assert_select ".monitor-name", text: "Old site", count: 0
    assert_select "form[action=?]", subscribers_path
  end

  test "shows open incidents with their updates and recent resolved ones" do
    open = Incident.open!(title: "Checkout fails", body: "We are on it.", impact: :major)
    done = Incident.open!(title: "Slow search", body: "Looking.")
    done.post_update!(status: :resolved, body: "Fixed.")

    get root_path

    assert_select "#overall", text: /Partial outage/
    assert_select "#incidents #incident_#{open.id}", text: /We are on it\./
    assert_select "#past-incidents #incident_#{done.id}", text: /Fixed\./
  end

  test "does not show monitor URLs to the public" do
    get root_path
    assert_no_match "api.example.com", response.body
  end

  test "status.json summarises the page" do
    uptime_monitors(:website).daily_uptimes.create!(date: Date.current, checks_count: 4, up_count: 3)
    incident = Incident.open!(title: "Checkout fails", body: "We are on it.", impact: :major)

    get status_summary_path(format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type
    json = response.parsed_body
    assert_equal({ "indicator" => "major", "description" => "Partial outage" }, json["status"])
    assert_equal %w[API Website], json["monitors"].pluck("name")
    website = json["monitors"].find { |monitor| monitor["name"] == "Website" }
    assert_equal 75.0, website["uptime_90d"]
    assert_equal "http://www.example.com/badge/#{uptime_monitors(:website).id}.svg", website["badge_url"]
    assert_not website.key?("url")
    assert_equal [ incident.id ], json["incidents"].pluck("id")
    assert_equal "We are on it.", json["incidents"].first["updates"].first["body"]
  end
end
