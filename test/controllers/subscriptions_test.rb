require "test_helper"

class SubscriptionsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { Rails.cache.clear } # the rate limit counts requests in the cache

  test "subscribe, confirm by link and unsubscribe" do
    assert_enqueued_emails 1 do
      post subscribers_path, params: { subscriber: { email_address: "New@Example.com" } }
    end
    assert_redirected_to root_path(anchor: "subscribe")
    subscriber = Subscriber.find_by!(email_address: "new@example.com")
    assert_not subscriber.confirmed?

    token = subscriber.generate_token_for(:confirmation)
    get subscription_confirmation_path(token)
    assert_response :success
    assert_not subscriber.reload.confirmed?, "opening the link alone does not confirm"

    post subscription_confirmation_path(token)
    assert_redirected_to root_path
    assert subscriber.reload.confirmed?

    unsubscribe_token = subscriber.generate_token_for(:unsubscribe)
    get unsubscribe_path(unsubscribe_token)
    assert_response :success
    assert_select "strong", "new@example.com"

    post unsubscribe_path(unsubscribe_token)
    assert_redirected_to root_path
    assert_not Subscriber.exists?(subscriber.id)
  end

  test "the same answer for a known address, and no e-mail" do
    assert_no_enqueued_emails do
      post subscribers_path, params: { subscriber: { email_address: "reader@example.com" } }
    end
    follow_redirect!
    assert_select ".flash-notice", /Check your inbox/
  end

  test "an invalid address is refused" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_path, params: { subscriber: { email_address: "nope" } }
    end
    follow_redirect!
    assert_select ".flash-alert", /valid e-mail address/
  end

  test "forged or used tokens are refused" do
    post subscription_confirmation_path("forged")
    assert_redirected_to root_path
    assert_equal "That confirmation link is invalid or has expired.", flash[:alert]

    post unsubscribe_path("forged")
    assert_equal "That unsubscribe link is invalid or was already used.", flash[:alert]
  end

  test "one-click unsubscribe from a mail client works without a CSRF token" do
    subscriber = subscribers(:confirmed)
    with_forgery_protection do
      post unsubscribe_path(subscriber.generate_token_for(:unsubscribe)), params: { "List-Unsubscribe" => "One-Click" }
    end
    assert_not Subscriber.exists?(subscriber.id)
  end

  test "subscribing is rate limited" do
    6.times { |n| post subscribers_path, params: { subscriber: { email_address: "flood#{n}@example.com" } } }
    follow_redirect!
    assert_select ".flash-alert", /Too many attempts/
  end

  private
    def with_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
end
