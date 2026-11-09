class IncidentsMailer < ApplicationMailer
  # Sent back when an e-mail to the incidents address cannot be accepted.
  def rejected(inbound_email, reason)
    @reason = reason
    @subject = inbound_email.mail.subject
    mail to: inbound_email.mail.from, subject: "Not accepted: #{@subject}"
  end
end
