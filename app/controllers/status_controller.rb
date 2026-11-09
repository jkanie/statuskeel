# The public status page (HTML at /, JSON at /status.json). No sign-in needed.
class StatusController < ApplicationController
  allow_unauthenticated_access

  def show
    @page = StatusPage.new
    @subscriber = Subscriber.new
  end
end
