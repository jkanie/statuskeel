# The incident updates as an Atom feed at /incidents.atom, newest at the top, for feed readers and
# for team messaging apps that post new feed entries. No sign-in needed: it holds what the public page shows.
class IncidentFeedsController < ApplicationController
  allow_unauthenticated_access

  LIMIT = 50

  def show
    @title = Rails.configuration.x.status_page_title
    @updates = IncidentUpdate.includes(:incident, :rich_text_body).order(created_at: :desc, id: :desc).limit(LIMIT).to_a

    expires_in 1.minute, public: true
    # A feed reader that sends back the ETag gets 304 Not Modified, with no body, until an entry changes. Each
    # entry shows its incident's title and impact as well, so the incidents are part of the tag.
    fresh_when etag: [ @title, @updates, @updates.map(&:incident).uniq ], public: true
  end
end
