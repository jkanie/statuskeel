class SubscriberMailer < ApplicationMailer
  def confirmation(subscriber)
    @subscriber = subscriber
    @title = Rails.configuration.x.status_page_title
    @confirm_url = subscription_confirmation_url(subscriber.generate_token_for(:confirmation))
    mail to: subscriber.email_address, subject: "Confirm your subscription to #{@title}"
  end

  def incident_update(subscriber, update)
    @update = update
    @incident = update.incident
    @title = Rails.configuration.x.status_page_title
    @unsubscribe_url = unsubscribe_url(subscriber.generate_token_for(:unsubscribe))

    # RFC 8058 one-click unsubscribe: mail clients POST to this URL.
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail to: subscriber.email_address,
         subject: "[#{@title}] #{update.status.humanize}: #{@incident.title}"
  end
end
