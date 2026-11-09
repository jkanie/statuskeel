# Unsubscribe from the link in every e-mail. The POST also serves RFC 8058 one-click
# unsubscribe from mail clients, which send no CSRF token. The signed token authorises it.
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :create
  before_action :set_subscriber

  def show
  end

  def create
    @subscriber.destroy!
    redirect_to root_path, notice: "You are unsubscribed. Your e-mail address has been deleted."
  end

  private
    def set_subscriber
      @subscriber = Subscriber.find_by_token_for(:unsubscribe, params[:token])
      redirect_to root_path, alert: "That unsubscribe link is invalid or was already used." unless @subscriber
    end
end
