# The subscribe form on the public page.
class SubscribersController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to root_path, alert: "Too many attempts. Try again later." }

  def create
    subscriber = Subscriber.subscribe(params.expect(subscriber: [ :email_address ])[:email_address])

    if subscriber.errors.any?
      redirect_to root_path(anchor: "subscribe"), alert: "Enter a valid e-mail address."
    else
      redirect_to root_path(anchor: "subscribe"), notice: "Check your inbox to confirm the subscription."
    end
  end
end
