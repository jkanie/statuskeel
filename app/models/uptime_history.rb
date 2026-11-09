# The daily bars and the uptime percentage of 1 monitor over the last N days.
class UptimeHistory
  Bar = Data.define(:date, :percent) do
    def level
      if percent.nil? then "none"
      elsif percent >= 99.9 then "good"
      elsif percent >= 95 then "warn"
      else "bad"
      end
    end
  end

  # Rounds down, so 99.999 % shows as 99.99 % and never as 100 %.
  def self.percent(up_count, checks_count)
    return nil if checks_count.to_i.zero?

    (up_count * 10_000 / checks_count) / 100.0
  end

  attr_reader :days, :today

  def initialize(rows, days:, today:)
    @rows = rows.to_a
    @days = days
    @today = today
  end

  def bars
    by_date = @rows.index_by(&:date)
    ((today - (days - 1))..today).map do |date|
      row = by_date[date]
      Bar.new(date:, percent: row&.percent)
    end
  end

  def percent
    self.class.percent(@rows.sum(&:up_count), @rows.sum(&:checks_count))
  end
end
