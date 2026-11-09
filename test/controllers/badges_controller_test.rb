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
