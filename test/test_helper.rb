ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "turbo/broadcastable/test_helper"
require_relative "test_helpers/session_test_helper"

# Tests never reach the network. System tests still talk to their own local server.
WebMock.disable_net_connect!(allow_localhost: true)

# Made-up DNS for tests: every name resolves to a documentation address (RFC 5737)
# unless a test lists it here.
TEST_DNS = {
  "intranet.example.com" => [ "10.0.0.5" ],
  "metadata.example.com" => [ "169.254.169.254" ],
  "nowhere.example.com" => []
}.freeze
TargetGuard.resolver = ->(host) { TEST_DNS.fetch(host, [ "203.0.113.10" ]) }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper
    include Turbo::Broadcastable::TestHelper

    # Runs the block with ALLOW_PRIVATE_TARGETS switched on.
    def with_private_targets_allowed
      previous = Rails.configuration.x.allow_private_targets
      Rails.configuration.x.allow_private_targets = true
      yield
    ensure
      Rails.configuration.x.allow_private_targets = previous
    end

    def up_result(status: 200, ms: 120)
      HttpProbe::Result.new(up: true, http_status: status, response_time_ms: ms, error: nil)
    end

    def down_result(error: "expected HTTP 200 to 399, got 503")
      HttpProbe::Result.new(up: false, http_status: 503, response_time_ms: 80, error:)
    end
  end
end
