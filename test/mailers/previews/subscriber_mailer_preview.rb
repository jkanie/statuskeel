# Preview all emails at http://localhost:3000/rails/mailers/subscriber_mailer
class SubscriberMailerPreview < ActionMailer::Preview
  def confirmation
    SubscriberMailer.confirmation(Subscriber.first || Subscriber.new(id: 0, email_address: "reader@example.com"))
  end

  def incident_update
    subscriber = Subscriber.first || Subscriber.new(id: 0, email_address: "reader@example.com")
    SubscriberMailer.incident_update(subscriber, IncidentUpdate.last)
  end
end
