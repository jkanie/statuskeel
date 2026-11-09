# A URL that statuskeel checks on a schedule. The class is not called Monitor
# because Ruby already defines ::Monitor (the reentrant lock).
class UptimeMonitor < ApplicationRecord
  CHECK_FIELDS = %w[status consecutive_failures last_checked_at next_check_at updated_at].freeze
  HISTORY_DAYS = 90

  has_many :checks, dependent: :delete_all
  has_many :daily_uptimes, dependent: :delete_all
  has_many :incidents, dependent: :nullify

  enum :status, { pending: "pending", up: "up", down: "down" }, validate: true

  normalizes :url, with: ->(url) { url.strip }
  normalizes :keyword, with: ->(keyword) { keyword.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true, length: { maximum: 2000 }
  validates :interval_seconds, numericality: { only_integer: true, in: 30..86_400 }
  validates :timeout_seconds, numericality: { only_integer: true, in: 1..60 }
  validates :expected_status_min, :expected_status_max, numericality: { only_integer: true, in: 100..599 }
  validates :failure_threshold, numericality: { only_integer: true, in: 1..20 }
  validates :keyword, length: { maximum: 200 }
  validate :url_is_public_http
  validate :expected_statuses_are_ordered

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }
  scope :due, ->(at = Time.current) { active.where(next_check_at: nil).or(active.where(next_check_at: ..at)) }

  before_save :schedule_soon, if: -> { will_save_change_to_url? || will_save_change_to_interval_seconds? || will_save_change_to_active? }
  after_create_commit -> { StatusPage.broadcast_monitors }
  after_destroy_commit -> { StatusPage.broadcast_monitors }
  after_update_commit :broadcast_change

  def expected_statuses
    expected_status_min..expected_status_max
  end

  # Stores the result of 1 check, updates the state and opens or resolves the automatic incident.
  def record_check!(result, at: Time.current)
    transaction do
      checks.create!(up: result.up, http_status: result.http_status, response_time_ms: result.response_time_ms,
                     error: result.error&.truncate(500), checked_at: at)
      DailyUptime.record!(self, at.to_date, up: result.up)

      if result.up
        self.consecutive_failures = 0
        self.status = :up
      else
        self.consecutive_failures += 1
        self.status = :down if consecutive_failures >= failure_threshold
      end
      self.last_checked_at = at
      save!

      if result.up
        resolve_automatic_incidents(result)
      elsif consecutive_failures == failure_threshold && incidents.unresolved.none?
        open_automatic_incident(result)
      end
    end
  end

  def history(days: HISTORY_DAYS, today: Time.current.to_date, rows: nil)
    rows ||= daily_uptimes.where(date: (today - (days - 1))..today)
    UptimeHistory.new(rows, days:, today:)
  end

  private
    def url_is_public_http
      return if url.blank?

      uri = URI.parse(url)
      if !uri.is_a?(URI::HTTP) || uri.host.blank?
        errors.add(:url, "must be an http or https URL")
      elsif uri.userinfo.present?
        errors.add(:url, "must not contain a user name or password")
      else
        TargetGuard.resolve!(uri.hostname)
      end
    rescue URI::InvalidURIError
      errors.add(:url, "is not a valid URL")
    rescue TargetGuard::Refused => error
      # A host that does not resolve yet is allowed. The check refuses it again at run time.
      errors.add(:url, "is refused: #{error.message}") unless error.message.end_with?("does not resolve")
    end

    def expected_statuses_are_ordered
      return unless expected_status_min.is_a?(Integer) && expected_status_max.is_a?(Integer)

      errors.add(:expected_status_max, "must be at least the minimum") if expected_status_max < expected_status_min
    end

    def schedule_soon
      self.next_check_at = nil
    end

    def broadcast_change
      if (saved_changes.keys - CHECK_FIELDS).empty?
        StatusPage.broadcast_monitor(self)
      else
        StatusPage.broadcast_monitors
      end
    end

    def open_automatic_incident(result)
      incident = incidents.create!(title: "#{name} is down", impact: :major, status: :investigating,
                                   automatic: true, started_at: last_checked_at)
      incident.post_update!(body: "Opened automatically after #{consecutive_failures} failed checks in a row. " \
                                  "Last error: #{result.error}.")
    end

    def resolve_automatic_incidents(result)
      incidents.unresolved.where(automatic: true).find_each do |incident|
        incident.post_update!(status: :resolved, body: "Resolved automatically: #{name} responded with " \
                                                       "HTTP #{result.http_status} in #{result.response_time_ms} ms.")
      end
    end
end
