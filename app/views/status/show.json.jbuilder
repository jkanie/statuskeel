json.page do
  json.title @page.title
  json.url root_url
  json.generated_at Time.current.utc.iso8601
end

json.status do
  json.indicator @page.indicator
  json.description @page.description
end

json.monitors @page.monitors do |monitor|
  history = @page.history_for(monitor)
  json.id monitor.id
  json.name monitor.name
  json.status monitor.status
  json.uptime_90d history.percent
  json.last_checked_at monitor.last_checked_at&.utc&.iso8601
  json.badge_url badge_url(monitor, format: :svg)
end

json.incidents @page.active_incidents do |incident|
  json.id incident.id
  json.title incident.title
  json.status incident.status
  json.impact incident.impact
  json.started_at incident.started_at.utc.iso8601
  json.updates incident.updates do |update|
    json.status update.status
    json.body update.body.to_plain_text
    json.created_at update.created_at.utc.iso8601
  end
end

# The same incidents as "Resolved in the last 14 days" on the page (the 5 most recent).
json.resolved_incidents @page.resolved_incidents do |incident|
  json.id incident.id
  json.title incident.title
  json.impact incident.impact
  json.started_at incident.started_at.utc.iso8601
  json.resolved_at incident.resolved_at.utc.iso8601
  json.duration_seconds incident.duration.to_i
end
