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

  test "finds subscribers by part of the address, in any case" do
    Subscriber.create!(email_address: "ops_team@example.org")

    get admin_subscribers_path, params: { q: " READER " }
    assert_select "tbody td", text: "reader@example.com"
    assert_select "tbody tr", 1
    assert_select "p", text: /1 address holding "READER"/
    assert_select "input[name=q][value=READER]"

    # _ matches as written, not as a LIKE wild card that would find "rea" in reader@example.com.
    get admin_subscribers_path, params: { q: "r_a" }
    assert_select "tbody tr", 0
    get admin_subscribers_path, params: { q: "ops_" }
    assert_select "tbody td", text: "ops_team@example.org"
    assert_select "tbody tr", 1

    get admin_subscribers_path, params: { q: "example" }
    assert_select "tbody tr", 3
    get admin_subscribers_path
    assert_select "tbody tr", 3
  end

  test "keeps only the confirmed or the waiting addresses" do
    get admin_subscribers_path, params: { state: "confirmed" }
    assert_select "tbody td", text: "reader@example.com"
    assert_select "tbody tr", 1
    assert_select "p", text: /1 address confirmed\./

    get admin_subscribers_path, params: { state: "waiting" }
    assert_select "tbody td", text: "maybe@example.com"
    assert_select "tbody tr", 1
    assert_select "p", text: /1 address waiting\./

    # The state works with the search, and the form keeps it.
    get admin_subscribers_path, params: { state: "waiting", q: "READER" }
    assert_select "tbody tr", 0
    assert_select "p", text: /0 addresses waiting holding "READER"/
    assert_select "input[type=hidden][name=state][value=waiting]"
    assert_select "a[href=?]", admin_subscribers_path(state: "confirmed", q: "READER"), text: "1 confirmed"

    get admin_subscribers_path, params: { state: "everyone" }
    assert_select "tbody tr", 2
    assert_select "input[name=state]", 0
  end
end
