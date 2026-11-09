# An e-mail address that receives incident e-mails after it confirms the subscription.
class Subscriber < ApplicationRecord
  UNCONFIRMED_LIFETIME = 3.days

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, length: { maximum: 254 },
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  # Confirmation links expire and stop working once used.
  generates_token_for :confirmation, expires_in: UNCONFIRMED_LIFETIME do
    confirmed_at
  end

  # Unsubscribe links work for as long as the subscriber exists.
  generates_token_for :unsubscribe

  # Creates the subscriber if needed and sends the confirmation e-mail. Answers the same
  # way for new and known addresses, so the form does not reveal who subscribed.
  def self.subscribe(email_address)
    subscriber = find_or_initialize_by(email_address:)
    return subscriber unless subscriber.save

    SubscriberMailer.confirmation(subscriber).deliver_later unless subscriber.confirmed?
    subscriber
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end
end
