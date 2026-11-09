require "test_helper"

class SubscriberTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "normalises and validates the e-mail address" do
    assert_equal "new@example.com", Subscriber.new(email_address: "  NEW@Example.com ").email_address
    assert_not Subscriber.new(email_address: "not an address").valid?
    assert_not Subscriber.new(email_address: "READER@example.com").valid?, "duplicates are refused"
  end

  test "subscribe creates an unconfirmed subscriber and sends the confirmation e-mail" do
    assert_difference -> { Subscriber.count } => 1 do
      assert_enqueued_email_with SubscriberMailer, :confirmation, args: ->(args) { args.first.email_address == "new@example.com" } do
        Subscriber.subscribe("new@example.com")
      end
    end
    assert_not Subscriber.find_by!(email_address: "new@example.com").confirmed?
  end

  test "subscribe sends nothing for an address that is already confirmed" do
    assert_no_enqueued_emails do
      Subscriber.subscribe("reader@example.com")
    end
  end

  test "the confirmation token confirms once" do
    subscriber = subscribers(:unconfirmed)
    token = subscriber.generate_token_for(:confirmation)

    assert_equal subscriber, Subscriber.find_by_token_for(:confirmation, token)
    subscriber.confirm!
    assert_nil Subscriber.find_by_token_for(:confirmation, token), "a used link stops working"
  end

  test "the confirmation token expires after 3 days" do
    subscriber = subscribers(:unconfirmed)
    token = subscriber.generate_token_for(:confirmation)

    travel 3.days + 1.minute do
      assert_nil Subscriber.find_by_token_for(:confirmation, token)
    end
  end

  test "the unsubscribe token finds the subscriber" do
    subscriber = subscribers(:confirmed)
    assert_equal subscriber, Subscriber.find_by_token_for(:unsubscribe, subscriber.generate_token_for(:unsubscribe))
    assert_nil Subscriber.find_by_token_for(:unsubscribe, "forged")
  end
end
