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

  test "down-loads the list as CSV, with the same filters" do
    travel_to Time.utc(2027, 3, 10, 12) do
      get admin_subscribers_path(format: :csv)
      assert_response :success
      assert_equal "text/csv", response.media_type
      assert_match(/attachment; filename="subscribers-2027-03-10\.csv"/, response.headers["Content-Disposition"])
      confirmed, unconfirmed = subscribers(:confirmed), subscribers(:unconfirmed)
      rows = [ confirmed, unconfirmed ].sort_by { |s| [ s.created_at, s.id ] }.reverse.map do |s|
        [ s.email_address, s.confirmed_at&.utc&.iso8601, s.created_at.utc.iso8601 ].join(",")
      end
      assert_equal [ "email_address,confirmed_at,subscribed_at", *rows ].join("\n") + "\n", response.body
      assert_includes response.body, "\nmaybe@example.com,,"

      get admin_subscribers_path(format: :csv, state: "confirmed")
      assert_equal 2, response.body.lines.size
      assert_match(/\Areader@example\.com,\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ,/, response.body.lines.last)

      get admin_subscribers_path(format: :csv, q: "nobody")
      assert_equal "email_address,confirmed_at,subscribed_at\n", response.body
    end

    get admin_subscribers_path, params: { state: "waiting", q: "MAYBE" }
    assert_select "a[href=?]", admin_subscribers_path(format: :csv, state: "waiting", q: "MAYBE"),
                  text: "Down-load this list as CSV"
  end
end
