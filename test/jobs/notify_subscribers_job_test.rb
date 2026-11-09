require "test_helper"

class NotifySubscribersJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "e-mails each confirmed subscriber, not the unconfirmed ones" do
    incident = Incident.open!(title: "Login errors", body: "Looking into it.")
    update = incident.updates.sole

    assert_enqueued_emails 1 do
      NotifySubscribersJob.perform_now(update)
    end
    assert_enqueued_email_with SubscriberMailer, :incident_update, args: [ subscribers(:confirmed), update ]
  end
end
