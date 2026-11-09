# Lets admins run incidents from their mail client. The sender must be an admin's address.
# This trusts the From header, so the mail server in front must check SPF, DKIM, DMARC before it relays a message.
class IncidentsMailbox < ApplicationMailbox
  before_processing :require_admin_sender

  def process
    if (id = incident_id)
      incident = Incident.find_by(id:)
      return reject("there is no incident #{id}") unless incident

      incident.post_update!(body:)
    else
      Incident.open!(title: mail.subject.presence || "Untitled incident", body:)
    end
  end

  private
    def require_admin_sender
      reject("only admins can open or update incidents by e-mail") unless User.exists?(email_address: sender)
    end

    def reject(reason)
      bounce_with IncidentsMailer.rejected(inbound_email, reason)
    end

    def sender
      mail.from_address&.address.to_s.downcase
    end

    def incident_id
      mail.recipients.each do |address|
        match = INCIDENTS_ADDRESS.match(address)
        return match[1] if match
      end
      nil
    end

    # The new text of the e-mail as HTML paragraphs, without the quoted message of a reply.
    def body
      text = (mail.text_part || mail.html_part || mail).decoded.to_s
      text = ActionController::Base.helpers.strip_tags(text) if (mail.html_part && !mail.text_part) || mail.mime_type == "text/html"
      lines = text.lines.take_while { |line| !line.match?(/\AOn .+ wrote:\s*\z/) }
      text = lines.reject { |line| line.start_with?(">") }.join.strip
      ActionController::Base.helpers.simple_format(text.presence || "(no text)")
    end
end
