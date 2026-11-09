require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "visitors connect without signing in" do
    connect
    assert_nil connection.current_user
  end

  test "a signed-in admin is identified" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id

    connect
    assert_equal users(:one), connection.current_user
  end
end
