atom_feed(root_url: root_url) do |feed|
  feed.title "#{@title} incidents"
  feed.updated @updates.first&.created_at || Time.zone.at(0)
  feed.author { |author| author.name @title }

  @updates.each do |update|
    incident = update.incident
    feed.entry update, url: root_url(anchor: dom_id(incident)), published: update.created_at, updated: update.created_at do |entry|
      entry.title "#{update.status.humanize}: #{incident.title}"
      entry.content update.body.to_s, type: "html"
      entry.category term: incident.impact, label: "Impact: #{incident.impact.humanize}"
    end
  end
end
