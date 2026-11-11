module ApplicationHelper
  # A length of time in whole days, hours, minutes (largest unit at the front): "2 hours 5 minutes", "1 day 3 hours".
  # Seconds are dropped, and anything under 1 minute is "under 1 minute".
  def duration_in_words(seconds)
    minutes = (seconds / 60).floor
    return "under 1 minute" if minutes < 1

    parts = { "day" => minutes / 1440, "hour" => minutes % 1440 / 60, "minute" => minutes % 60 }
    parts.reject { |_, n| n.zero? }.map { |unit, n| "#{n} #{unit.pluralize(n)}" }.join(" ")
  end
end
