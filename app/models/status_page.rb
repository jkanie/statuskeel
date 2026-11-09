# What the public page shows, and the Turbo Stream broadcasts that keep it current.
class StatusPage
  STREAM = "status_page"

  DESCRIPTIONS = {
    "none" => "All systems operational",
    "minor" => "Minor service disruption",
    "major" => "Partial outage",
    "critical" => "Major outage"
  }.freeze

  class << self
    def broadcast_monitor(monitor)
      page = new
      broadcast_overall(page)
      return unless monitor.active?

      Turbo::StreamsChannel.broadcast_replace_to STREAM, target: ActionView::RecordIdentifier.dom_id(monitor),
        partial: "status/monitor", locals: { monitor:, history: page.history_for(monitor) }
    end

    def broadcast_monitors
      page = new
      broadcast_overall(page)
      Turbo::StreamsChannel.broadcast_replace_to STREAM, target: "monitors", partial: "status/monitors", locals: { page: }
    end

    def broadcast_incidents
      page = new
      broadcast_overall(page)
      Turbo::StreamsChannel.broadcast_replace_to STREAM, target: "incidents", partial: "status/incidents", locals: { page: }
      Turbo::StreamsChannel.broadcast_replace_to STREAM, target: "past-incidents", partial: "status/past_incidents", locals: { page: }
    end

    private
      def broadcast_overall(page)
        Turbo::StreamsChannel.broadcast_replace_to STREAM, target: "overall", partial: "status/overall", locals: { page: }
      end
  end

  def initialize(today: Time.current.to_date)
    @today = today
  end

  def title
    Rails.configuration.x.status_page_title
  end

  def monitors
    @monitors ||= UptimeMonitor.active.ordered.to_a
  end

  def history_for(monitor)
    rows = daily_uptimes.fetch(monitor.id, [])
    monitor.history(today: @today, rows:)
  end

  def active_incidents
    @active_incidents ||= Incident.unresolved.newest_first.includes(updates: :rich_text_body).to_a
  end

  def resolved_incidents
    @resolved_incidents ||= Incident.recently_resolved.limit(5).includes(updates: :rich_text_body).to_a
  end

  # 1 of Incident::IMPACTS: the worst level among the open incidents and the monitors that are down.
  def indicator
    levels = active_incidents.map(&:impact)
    down = monitors.count(&:down?)
    levels << (down == monitors.size ? "critical" : "major") if down.positive?
    levels.max_by { |level| Incident::IMPACTS.index(level) } || "none"
  end

  def description
    DESCRIPTIONS.fetch(indicator)
  end

  private
    def daily_uptimes
      @daily_uptimes ||= DailyUptime
        .where(uptime_monitor_id: monitors.map(&:id), date: (@today - (UptimeMonitor::HISTORY_DAYS - 1))..@today)
        .group_by(&:uptime_monitor_id)
    end
end
