# The result of 1 HTTP check of a monitor.
class Check < ApplicationRecord
  belongs_to :uptime_monitor

  scope :recent, -> { order(checked_at: :desc, id: :desc) }
  scope :older_than, ->(time) { where(checked_at: ...time) }
end
