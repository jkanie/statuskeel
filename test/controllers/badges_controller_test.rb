require "test_helper"

class BadgesControllerTest < ActionDispatch::IntegrationTest
  test "returns an SVG badge with the state and uptime" do
    monitor = uptime_monitors(:website)
    monitor.daily_uptimes.create!(date: Date.current, checks_count: 10_000, up_count: 9_998)

    get badge_path(monitor, format: :svg)

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_equal "max-age=60, public", response.headers["Cache-Control"]
    assert_includes response.body, "<title>Website: up 99.98%</title>"
    assert_includes response.body, BadgesController::COLOURS["up"]
  end

  test "days picks the span of the uptime figure" do
    monitor = uptime_monitors(:website)
    monitor.daily_uptimes.create!(date: Date.current, checks_count: 100, up_count: 100)
    monitor.daily_uptimes.create!(date: Date.current - 10, checks_count: 100, up_count: 50)
    monitor.daily_uptimes.create!(date: Date.current - 40, checks_count: 100, up_count: 0)

    { nil => "Website: up 50.00%", 90 => "Website: up 50.00%", 30 => "Website (30 days): up 75.00%",
      7 => "Website (7 days): up 100.00%" }.each do |days, title|
      get badge_path(monitor, format: :svg, days: days)
      assert_response :success
      assert_includes response.body, "<title>#{title}</title>"
    end

    # No check in the span: the state alone, as for a new monitor.
    monitor.daily_uptimes.where("date > ?", Date.current - 7).delete_all
    get badge_path(monitor, format: :svg, days: 7)
    assert_includes response.body, "<title>Website (7 days): up</title>"

    [ 1, 365, "seven", "" ].each do |days|
      get badge_path(monitor, format: :svg, days: days)
      assert_response :bad_request, "days=#{days.inspect}"
    end
  end

  test "escapes the monitor name" do
    monitor = uptime_monitors(:website)
    monitor.update_columns(name: "<script>x</script>")
    get badge_path(monitor, format: :svg)
    assert_not_includes response.body, "<script>"
  end

  test "no badge for paused or unknown monitors" do
    get badge_path(uptime_monitors(:paused), format: :svg)
    assert_response :not_found
    get "/badge/999999.svg"
    assert_response :not_found
  end
end
