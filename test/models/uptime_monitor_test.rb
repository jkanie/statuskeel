require "test_helper"

class UptimeMonitorTest < ActiveSupport::TestCase
  def build(**attributes)
    UptimeMonitor.new(name: "Shop", url: "https://shop.example.com", **attributes)
  end

  test "defaults match the documented settings" do
    monitor = build
    assert monitor.valid?
    assert_equal 60, monitor.interval_seconds
    assert_equal 10, monitor.timeout_seconds
    assert_equal 200..399, monitor.expected_statuses
    assert_equal 2, monitor.failure_threshold
    assert monitor.active?
    assert monitor.pending?
  end

  test "accepts only http and https URLs" do
    assert build(url: "http://shop.example.com").valid?
    %w[ftp://shop.example.com file:///etc/passwd javascript:alert(1) shop.example.com].each do |url|
      monitor = build(url:)
      assert_not monitor.valid?, "#{url} should be invalid"
      assert_includes monitor.errors[:url], "must be an http or https URL"
    end
  end

  test "refuses URLs with a user name or password" do
    monitor = build(url: "https://user:secret@shop.example.com")
    assert_not monitor.valid?
    assert_includes monitor.errors[:url], "must not contain a user name or password"
  end

  test "refuses private and loopback targets (SSRF)" do
    {
      "http://127.0.0.1:3000/" => "127.0.0.1",
      "http://[::1]/" => "::1",
      "http://169.254.169.254/latest/meta-data/" => "169.254.169.254",
      "https://intranet.example.com/" => "10.0.0.5",
      "http://metadata.example.com/" => "169.254.169.254"
    }.each do |url, address|
      monitor = build(url:)
      assert_not monitor.valid?, "#{url} should be refused"
      assert_match "resolves to #{address}, a private or reserved address", monitor.errors[:url].first
    end
  end

  test "allows private targets when ALLOW_PRIVATE_TARGETS is on" do
    with_private_targets_allowed do
      assert build(url: "http://127.0.0.1:3000/up").valid?
    end
  end

  test "allows a host that does not resolve yet, the check refuses it later" do
    assert build(url: "https://nowhere.example.com").valid?
  end

  test "validates ranges and the order of the expected statuses" do
    assert_not build(interval_seconds: 10).valid?
    assert_not build(timeout_seconds: 0).valid?
    assert_not build(failure_threshold: 0).valid?
    monitor = build(expected_status_min: 300, expected_status_max: 200)
    assert_not monitor.valid?
    assert_includes monitor.errors[:expected_status_max], "must be at least the minimum"
  end

  test "a blank keyword is stored as nil" do
    assert_nil build(keyword: "").keyword
  end

  test "due lists active monitors that were never scheduled or are past their next check" do
    uptime_monitors(:website).update_columns(next_check_at: 1.minute.ago)
    uptime_monitors(:api).update_columns(next_check_at: 1.minute.from_now)

    due = UptimeMonitor.due
    assert_includes due, uptime_monitors(:website)
    assert_not_includes due, uptime_monitors(:api)
    assert_not_includes due, uptime_monitors(:paused)
  end

  test "changing the URL schedules the next check right away" do
    monitor = uptime_monitors(:api)
    monitor.update!(url: "https://api.example.com/v2/health")
    assert_nil monitor.next_check_at
  end

  test "record_check! stores the check and the daily count" do
    monitor = uptime_monitors(:website)

    assert_difference -> { monitor.checks.count } => 1, -> { DailyUptime.count } => 1 do
      monitor.record_check!(up_result(ms: 87))
    end

    check = monitor.checks.recent.first
    assert check.up?
    assert_equal 200, check.http_status
    assert_equal 87, check.response_time_ms
    assert_equal [ 1, 1 ], monitor.daily_uptimes.pick(:checks_count, :up_count)
  end

  test "daily counts add up within a day" do
    monitor = uptime_monitors(:website)
    at = Time.utc(2026, 11, 9, 12)
    monitor.record_check!(up_result, at:)
    monitor.record_check!(up_result, at: at + 1.minute)
    monitor.record_check!(down_result, at: at + 2.minutes)

    row = monitor.daily_uptimes.find_by!(date: Date.new(2026, 11, 9))
    assert_equal 3, row.checks_count
    assert_equal 2, row.up_count
    assert_equal 66.66, row.percent
  end

  test "history gives 90 bars ending today and the uptime percentage" do
    monitor = uptime_monitors(:website)
    today = Date.new(2026, 11, 9)
    monitor.daily_uptimes.create!(date: today, checks_count: 1440, up_count: 1440)
    monitor.daily_uptimes.create!(date: today - 1, checks_count: 1440, up_count: 1368)
    monitor.daily_uptimes.create!(date: today - 120, checks_count: 10, up_count: 0)

    history = monitor.history(today:)
    assert_equal 90, history.bars.size
    assert_equal today, history.bars.last.date
    assert_equal "good", history.bars.last.level
    assert_equal "warn", history.bars[-2].level
    assert_equal "none", history.bars.first.level
    assert_equal 97.5, history.percent
  end
end
