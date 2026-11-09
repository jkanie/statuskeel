# Made-up sample data for development: 3 monitors and 1 resolved incident.
# Run with bin/rails db:seed. It is safe to run more than once.
# bin/rails db:prepare runs this file when it creates a database, so production is skipped.
return if Rails.env.production?

monitors = [
  { name: "Website", url: "https://example.com", keyword: "Example Domain" },
  { name: "API", url: "https://example.org/", interval_seconds: 120 },
  { name: "Docs", url: "https://example.net/", interval_seconds: 300, failure_threshold: 3 }
]

monitors.each do |attributes|
  UptimeMonitor.find_or_create_by!(name: attributes[:name]) do |monitor|
    monitor.assign_attributes(attributes)
  end
end

unless Incident.exists?(title: "Slow responses from the API")
  api = UptimeMonitor.find_by!(name: "API")
  incident = Incident.open!(title: "Slow responses from the API", impact: :minor, uptime_monitor: api,
                            started_at: 2.days.ago, body: "We are looking into slow responses from the API.")
  incident.post_update!(status: :resolved, body: "A cache node was replaced. Response times are back to normal.")
end
