require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "duration_in_words names whole days, hours, minutes with the largest unit at the front" do
    assert_equal "under 1 minute", duration_in_words(0)
    assert_equal "under 1 minute", duration_in_words(59.9)
    assert_equal "1 minute", duration_in_words(60)
    assert_equal "2 minutes", duration_in_words(179)
    assert_equal "1 hour", duration_in_words(3600)
    assert_equal "2 hours 5 minutes", duration_in_words(2.hours + 5.minutes + 30.seconds)
    assert_equal "1 day 3 hours", duration_in_words(27.hours)
    assert_equal "3 days 1 minute", duration_in_words(3.days + 1.minute)
  end
end
