# Runs 1 HTTP check and records it. At most 1 check per monitor runs at a time.
class CheckMonitorJob < ApplicationJob
  queue_as :checks
  limits_concurrency to: 1, key: ->(monitor) { monitor }, duration: 2.minutes, on_conflict: :discard
  discard_on ActiveJob::DeserializationError

  def perform(monitor)
    return unless monitor.active?

    monitor.record_check!(HttpProbe.new(monitor).call)
  end
end
