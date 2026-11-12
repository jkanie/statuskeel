# The public status page (HTML at /, JSON at /status.json). No sign-in needed.
class StatusController < ApplicationController
  allow_unauthenticated_access

  def show
    @page = StatusPage.new
    @subscriber = Subscriber.new

    # The JSON is the same for every caller, as the badges and the feed are, so caches may keep it for 1 minute.
    # The HTML page holds the subscribe form with its per-session token, so it stays private.
    expires_in 1.minute, public: true if request.format.json?
  end
end
