require "net/http"

# Runs 1 HTTP check for a monitor and reports whether it passed.
class HttpProbe
  Result = Data.define(:up, :http_status, :response_time_ms, :error)

  MAX_REDIRECTS = 3
  MAX_BODY_BYTES = 1.megabyte
  USER_AGENT = "statuskeel (+https://github.com/jkanie/statuskeel)".freeze

  class Failure < StandardError; end
  class StopReading < StandardError; end

  attr_reader :monitor

  def initialize(monitor)
    @monitor = monitor
  end

  def call
    started = now
    response, body = fetch_following_redirects(URI.parse(monitor.url), started)
    evaluate(response, body, elapsed_ms(started))
  rescue TargetGuard::Refused, Failure => error
    failed(error.message, started)
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    failed("timed out after #{monitor.timeout_seconds} s", started)
  rescue OpenSSL::SSL::SSLError => error
    failed("TLS error: #{error.message}", started)
  rescue SocketError, SystemCallError, IOError, EOFError, Net::HTTPBadResponse, URI::Error => error
    failed(error.message, started)
  end

  private
    def fetch_following_redirects(uri, started)
      redirects = 0

      loop do
        address = TargetGuard.resolve!(uri.hostname).first
        response, body = fetch(uri, address, started)

        return [ response, body ] unless response.is_a?(Net::HTTPRedirection) && response["location"].present?
        raise Failure, "stopped after #{MAX_REDIRECTS} redirects" if redirects == MAX_REDIRECTS

        redirects += 1
        uri = URI.join(uri.to_s, response["location"])
        raise Failure, "redirected to a #{uri.scheme} URL" unless %w[http https].include?(uri.scheme)
      end
    end

    def fetch(uri, address, started)
      http = Net::HTTP.new(uri.hostname, uri.port, nil) # nil: never use a proxy from the environment
      http.ipaddr = address # connect to the address that TargetGuard approved
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = http.write_timeout = http.ssl_timeout = monitor.timeout_seconds

      deadline = started + monitor.timeout_seconds
      request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "*/*")
      response = nil
      body = +""

      begin
        http.start do
          http.request(request) do |res|
            response = res
            res.read_body do |chunk|
              body << chunk
              raise Net::ReadTimeout if now > deadline
              raise StopReading if body.bytesize >= MAX_BODY_BYTES
            end
          end
        end
      rescue StopReading
        # The first MAX_BODY_BYTES are enough to look for the keyword.
      end

      [ response, body ]
    end

    def evaluate(response, body, response_time_ms)
      status = response.code.to_i

      error =
        if !monitor.expected_statuses.cover?(status)
          "expected HTTP #{monitor.expected_status_min} to #{monitor.expected_status_max}, got #{status}"
        elsif monitor.keyword.present? && !body.dup.force_encoding(Encoding::UTF_8).scrub.include?(monitor.keyword)
          "keyword \"#{monitor.keyword}\" not found in the response body"
        end

      Result.new(up: error.nil?, http_status: status, response_time_ms:, error:)
    end

    def failed(message, started)
      Result.new(up: false, http_status: nil, response_time_ms: elapsed_ms(started), error: message)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(started)
      ((now - started) * 1000).round
    end
end
