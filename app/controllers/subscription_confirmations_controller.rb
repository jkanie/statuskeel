# The link in the confirmation e-mail shows a button, so link scanners that only GET do not confirm.
class SubscriptionConfirmationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_subscriber

  def show
  end

  def create
    @subscriber.confirm!
    redirect_to root_path, notice: "Subscription confirmed. You will get an e-mail for each incident update."
  end

  private
    def set_subscriber
      @subscriber = Subscriber.find_by_token_for(:confirmation, params[:token])
      redirect_to root_path, alert: "That confirmation link is invalid or has expired." unless @subscriber
    end
end
