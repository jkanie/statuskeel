require "test_helper"

class HttpProbeTest < ActiveSupport::TestCase
  setup do
    @monitor = UptimeMonitor.new(name: "Shop", url: "https://shop.example.com/health", timeout_seconds: 5)
  end

  def probe
    HttpProbe.new(@monitor).call
  end

  test "up for a 200 response" do
    stub_request(:get, "https://shop.example.com/health").to_return(status: 200, body: "ok")

    result = probe
    assert result.up
    assert_equal 200, result.http_status
    assert_kind_of Integer, result.response_time_ms
    assert_nil result.error
  end

  test "sends the statuskeel user agent" do
    stub = stub_request(:get, "https://shop.example.com/health").with(headers: { "User-Agent" => HttpProbe::USER_AGENT })
    probe
    assert_requested stub
  end

  test "down for a status outside the expected range" do
    stub_request(:get, "https://shop.example.com/health").to_return(status: 503)

    result = probe
    assert_not result.up
    assert_equal 503, result.http_status
    assert_equal "expected HTTP 200 to 399, got 503", result.error
  end

  test "honours a custom expected status range" do
    @monitor.expected_status_min = @monitor.expected_status_max = 401
    stub_request(:get, "https://shop.example.com/health").to_return(status: 401)
    assert probe.up
  end

  test "checks the keyword in the body" do
    @monitor.keyword = "All good"
    stub_request(:get, "https://shop.example.com/health").to_return(status: 200, body: "<h1>All good</h1>")
    assert probe.up

    stub_request(:get, "https://shop.example.com/health").to_return(status: 200, body: "<h1>Maintenance</h1>")
    result = probe
    assert_not result.up
    assert_equal "keyword \"All good\" not found in the response body", result.error
  end

  test "down with a clear error on a timeout" do
    stub_request(:get, "https://shop.example.com/health").to_timeout

    result = probe
    assert_not result.up
    assert_nil result.http_status
    assert_equal "timed out after 5 s", result.error
  end

  test "down when the connection is refused" do
    stub_request(:get, "https://shop.example.com/health").to_raise(Errno::ECONNREFUSED)

    result = probe
    assert_not result.up
    assert_match "Connection refused", result.error
  end

  test "follows up to 3 redirects" do
    stub_request(:get, "https://shop.example.com/health").to_return(status: 301, headers: { "Location" => "/health/" })
    stub_request(:get, "https://shop.example.com/health/").to_return(status: 302, headers: { "Location" => "https://www.example.com/up" })
    stub_request(:get, "https://www.example.com/up").to_return(status: 200, body: "ok")

    result = probe
    assert result.up
    assert_equal 200, result.http_status
  end

  test "stops after 3 redirects" do
    stub_request(:get, %r{\Ahttps://shop\.example\.com/}).to_return do |request|
      { status: 302, headers: { "Location" => "#{request.uri.path}x" } }
    end

    result = probe
    assert_not result.up
    assert_equal "stopped after 3 redirects", result.error
    assert_requested :get, %r{\Ahttps://shop\.example\.com/}, times: 4
  end

  test "refuses a redirect to a private address (SSRF)" do
    stub_request(:get, "https://shop.example.com/health").to_return(status: 302, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })

    result = probe
    assert_not result.up
    assert_equal "169.254.169.254 resolves to 169.254.169.254, a private or reserved address", result.error
    assert_not_requested :get, "http://169.254.169.254/latest/meta-data/"
  end

  test "refuses a host that now resolves to a private address (DNS rebinding)" do
    @monitor.url = "https://intranet.example.com/"

    result = probe
    assert_not result.up
    assert_equal "intranet.example.com resolves to 10.0.0.5, a private or reserved address", result.error
  end

  test "refuses a redirect to another scheme" do
    stub_request(:get, "https://shop.example.com/health").to_return(status: 301, headers: { "Location" => "ftp://shop.example.com/" })
    assert_equal "redirected to a ftp URL", probe.error
  end
end
