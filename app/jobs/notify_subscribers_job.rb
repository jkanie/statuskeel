# Sends 1 e-mail per confirmed subscriber for a new incident update.
class NotifySubscribersJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(update)
    Subscriber.confirmed.find_in_batches(batch_size: 500) do |subscribers|
      ActionMailer.deliver_all_later(subscribers.map { |subscriber| SubscriberMailer.incident_update(subscriber, update) })
    end
  end
end
