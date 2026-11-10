# The incident updates as an Atom feed at /incidents.atom, newest first, for feed readers and
# for team messaging apps that post new feed entries. No sign-in needed: it holds what the public page shows.
class IncidentFeedsController < ApplicationController
  allow_unauthenticated_access

  LIMIT = 50

  def show
    @title = Rails.configuration.x.status_page_title
    @updates = IncidentUpdate.includes(:incident, :rich_text_body).order(created_at: :desc, id: :desc).limit(LIMIT).to_a

    expires_in 1.minute, public: true
  end
end
