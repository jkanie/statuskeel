require "test_helper"

class SubscriberMailerTest < ActionMailer::TestCase
  test "confirmation e-mail carries a signed confirmation link" do
    subscriber = subscribers(:unconfirmed)
    mail = SubscriberMailer.confirmation(subscriber)

    assert_equal [ "maybe@example.com" ], mail.to
    assert_equal [ "status@example.com" ], mail.from
    assert_equal "Confirm your subscription to Statuskeel", mail.subject

    token = mail.text_part.body.to_s[%r{/subscription/confirm/(\S+)}, 1]
    assert_equal subscriber, Subscriber.find_by_token_for(:confirmation, token)
    assert_includes mail.html_part.body.to_s, "Confirm my subscription"
  end

  test "incident update e-mail has the update and an unsubscribe link and header" do
    subscriber = subscribers(:confirmed)
    incident = Incident.open!(title: "Login errors", body: "<p>Some users see <strong>errors</strong>.</p>")
    mail = SubscriberMailer.incident_update(subscriber, incident.updates.sole)

    assert_equal [ "reader@example.com" ], mail.to
    assert_equal "[Statuskeel] Investigating: Login errors", mail.subject
    assert_includes mail.text_part.body.to_s, "Some users see errors."
    assert_includes mail.html_part.body.to_s, "<strong>errors</strong>"

    unsubscribe_url = mail.header["List-Unsubscribe"].value[/<(.+)>/, 1]
    assert_equal "List-Unsubscribe=One-Click", mail.header["List-Unsubscribe-Post"].value
    assert_includes mail.text_part.body.to_s, "Unsubscribe: #{unsubscribe_url}"
    token = unsubscribe_url[%r{/subscription/unsubscribe/(\S+)}, 1]
    assert_equal subscriber, Subscriber.find_by_token_for(:unsubscribe, token)
  end

  test "the subject names a resolved incident" do
    incident = Incident.open!(title: "Login errors", body: "Looking.")
    incident.post_update!(status: :resolved, body: "Fixed.")
    mail = SubscriberMailer.incident_update(subscribers(:confirmed), incident.updates.first)
    assert_equal "[Statuskeel] Resolved: Login errors", mail.subject
  end
end
