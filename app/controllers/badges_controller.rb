# An SVG badge per monitor for READMEs, such as ![status](https://status.example.com/badge/1.svg).
class BadgesController < ApplicationController
  allow_unauthenticated_access

  COLOURS = { "up" => "#2e7d32", "down" => "#c62828", "pending" => "#757575" }.freeze
  # ?days= picks the span of the uptime figure. 90 days is the default, as on the status page.
  SPANS = [ 90, 30, 7 ].freeze

  def show
    @monitor = UptimeMonitor.active.find(params[:id])
    days = params.fetch(:days, SPANS.first).to_s
    return head :bad_request unless SPANS.map(&:to_s).include?(days)

    percent = @monitor.history.percent_over(days.to_i)
    @label = days.to_i == SPANS.first ? @monitor.name : "#{@monitor.name} (#{days} days)"
    @message = [ @monitor.status, (format("%.2f%%", percent) if percent) ].compact.join(" ")
    @colour = COLOURS.fetch(@monitor.status)

    expires_in 1.minute, public: true
    render formats: :svg
  end
end
