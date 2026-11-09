# Something that affects the service. A failing monitor opens 1 on its own. Admins open them on the admin screens or by e-mail.
class Incident < ApplicationRecord
  STATUSES = %w[investigating identified monitoring resolved].freeze
  IMPACTS = %w[none minor major critical].freeze

  belongs_to :uptime_monitor, optional: true
  has_many :updates, -> { order(created_at: :desc, id: :desc) }, class_name: "IncidentUpdate",
           dependent: :destroy, inverse_of: :incident

  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :impact, IMPACTS.index_by(&:itself), prefix: true, validate: true

  validates :title, presence: true, length: { maximum: 200 }

  scope :unresolved, -> { where.not(status: :resolved) }
  scope :newest_first, -> { order(started_at: :desc, id: :desc) }
  scope :recently_resolved, ->(since = 14.days.ago) { resolved.where(resolved_at: since..).order(resolved_at: :desc) }

  before_validation { self.started_at ||= Time.current }
  before_save :stamp_resolved_at
  after_commit -> { StatusPage.broadcast_incidents }

  # Opens an incident together with its first update.
  def self.open!(title:, body:, impact: :minor, status: :investigating, **attributes)
    transaction do
      create!(title:, impact:, status:, **attributes).tap { |incident| incident.post_update!(body:) }
    end
  end

  # Adds an update and moves the incident to the update's status. Subscribers get an e-mail.
  def post_update!(body:, status: self.status)
    transaction do
      update!(status:)
      updates.create!(status:, body:)
    end
  end

  private
    def stamp_resolved_at
      self.resolved_at = resolved? ? (resolved_at || Time.current) : nil
    end
end
