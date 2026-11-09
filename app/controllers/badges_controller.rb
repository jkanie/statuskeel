# An SVG badge per monitor for READMEs, such as ![status](https://status.example.com/badge/1.svg).
class BadgesController < ApplicationController
  allow_unauthenticated_access

  COLOURS = { "up" => "#2e7d32", "down" => "#c62828", "pending" => "#757575" }.freeze

  def show
    @monitor = UptimeMonitor.active.find(params[:id])
    percent = @monitor.history.percent
    @label = @monitor.name
    @message = [ @monitor.status, (format("%.2f%%", percent) if percent) ].compact.join(" ")
    @colour = COLOURS.fetch(@monitor.status)

    expires_in 1.minute, public: true
    render formats: :svg
  end
end
