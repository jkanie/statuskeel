require "test_helper"

class Admin::SubscribersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "lists and deletes subscribers" do
    get admin_subscribers_path
    assert_select "td", "reader@example.com"

    assert_difference -> { Subscriber.count } => -1 do
      delete admin_subscriber_path(subscribers(:confirmed))
    end
    assert_redirected_to admin_subscribers_path
  end
end
