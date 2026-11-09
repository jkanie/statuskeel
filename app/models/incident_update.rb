# 1 dated message on an incident, with a rich text body (Action Text).
class IncidentUpdate < ApplicationRecord
  belongs_to :incident, inverse_of: :updates
  has_rich_text :body

  enum :status, Incident::STATUSES.index_by(&:itself), validate: true

  validates :body, presence: true

  after_create_commit -> { NotifySubscribersJob.perform_later(self) }
end
