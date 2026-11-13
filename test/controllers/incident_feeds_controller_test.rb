require "test_helper"

class IncidentFeedsControllerTest < ActionDispatch::IntegrationTest
  test "the feed needs no sign-in and lists every update newest first" do
    checkout = Incident.open!(title: "Checkout fails", body: "We are on it.", impact: :major)
    travel 1.minute
    checkout.post_update!(status: :identified, body: "A bad <b>deploy</b> & a fix on the way.")
    travel 1.minute
    search = Incident.open!(title: "Slow search", body: "Looking.")

    get incidents_feed_path(format: :atom)

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_equal "max-age=60, public", response.headers["Cache-Control"]
    feed = Nokogiri::XML(response.body)
    feed.remove_namespaces!
    assert_equal "Statuskeel incidents", feed.at("/feed/title").text
    assert_equal "Statuskeel", feed.at("/feed/author/name").text
    assert_equal "tag:www.example.com,2005:/incidents", feed.at("/feed/id").text
    assert_equal [ "Investigating: Slow search", "Identified: Checkout fails", "Investigating: Checkout fails" ],
                 feed.xpath("/feed/entry/title").map(&:text)
    assert_equal search.updates.first.created_at.utc.iso8601, feed.at("/feed/updated").text

    entry = feed.xpath("/feed/entry")[1]
    assert_equal "http://www.example.com/#incident_#{checkout.id}", entry.at("link")["href"]
    assert_equal "major", entry.at("category")["term"]
    assert_equal "html", entry.at("content")["type"]
    # The rich text body goes in as HTML, escaped once inside the XML.
    assert_includes entry.at("content").text, "A bad <b>deploy</b> &amp; a fix on the way."
    assert_includes response.body, "A bad &lt;b&gt;deploy&lt;/b&gt; &amp;amp; a fix on the way."
    assert_equal 3, feed.xpath("/feed/entry/id").map(&:text).uniq.size
  end

  test "a feed reader with the current ETag gets 304 until an entry changes" do
    incident = Incident.open!(title: "Checkout fails", body: "We are on it.", impact: :major)
    get incidents_feed_path(format: :atom)
    assert_response :success
    etag = response.headers["ETag"]
    assert etag.present?

    get incidents_feed_path(format: :atom), headers: { "If-None-Match" => etag }
    assert_response :not_modified
    assert_empty response.body
    assert_equal "max-age=60, public", response.headers["Cache-Control"]

    # A new update, a new title, an edited body: each gives the full feed again with a new ETag.
    changes = [
      -> { incident.post_update!(status: :identified, body: "Found it.") },
      -> { incident.update!(title: "Checkout and cart fail") },
      -> { incident.updates.first.update!(body: "We are on it, with the payment team.") }
    ]
    changes.each do |change|
      travel 1.second
      change.call
      get incidents_feed_path(format: :atom), headers: { "If-None-Match" => etag }
      assert_response :success
      assert_not_equal etag, response.headers["ETag"]
      etag = response.headers["ETag"]
    end
  end

  test "an empty feed is still valid" do
    get incidents_feed_path(format: :atom)

    assert_response :success
    feed = Nokogiri::XML(response.body)
    feed.remove_namespaces!
    assert_empty feed.xpath("/feed/entry")
    assert_equal Time.zone.at(0).utc.iso8601, feed.at("/feed/updated").text
  end

  test "the feed stops at the newest 50 updates" do
    incident = Incident.open!(title: "Flapping", body: "Update 0")
    51.times { |n| travel(1.second) { incident.post_update!(body: "Update #{n + 1}") } }

    get incidents_feed_path(format: :atom)

    entries = Nokogiri::XML(response.body).remove_namespaces!.xpath("/feed/entry")
    assert_equal IncidentFeedsController::LIMIT, entries.size
    assert_includes entries.first.at("content").text, "Update 51"
  end

  test "the status page links to the feed" do
    get root_path

    assert_select "head link[rel=alternate][type='application/atom+xml'][href=?]", "http://www.example.com/incidents.atom"
    assert_select "footer a[href=?]", "/incidents.atom"
  end

  test "other formats are not routed" do
    get "/incidents.json"
    assert_response :not_found
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/incidents") }
  end
end
