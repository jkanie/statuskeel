require "test_helper"

class IncidentsMailboxTest < ActionMailbox::TestCase
  include ActionMailer::TestHelper

  test "routes incidents@ and incident+<id>@ to the incidents mailbox" do
    assert_equal IncidentsMailbox, ApplicationMailbox.router.mailbox_for(create_inbound_email_from_mail(to: "incidents@status.example.com", from: "one@example.com", subject: "x", body: "y"))
    assert_equal IncidentsMailbox, ApplicationMailbox.router.mailbox_for(create_inbound_email_from_mail(to: "incident+12@status.example.com", from: "one@example.com", subject: "x", body: "y"))
  end

  test "an admin's e-mail to incidents@ opens an incident" do
    assert_difference -> { Incident.count } => 1 do
      receive_inbound_email_from_mail \
        to: "incidents@status.example.com", from: "One <ONE@example.com>",
        subject: "Database failover", body: "We are failing over the primary database.\nExpect 5 minutes of errors."
    end

    incident = Incident.last
    assert_equal "Database failover", incident.title
    assert incident.investigating?
    assert_equal "We are failing over the primary database.\nExpect 5 minutes of errors.",
                 incident.updates.sole.body.to_plain_text
  end

  test "a reply to incident+<id>@ adds an update without the quoted text" do
    incident = Incident.open!(title: "Database failover", body: "Failing over.")

    assert_difference -> { incident.updates.count } => 1 do
      receive_inbound_email_from_mail \
        to: "incident+#{incident.id}@status.example.com", from: "two@example.com",
        subject: "Re: Database failover", body: "Failover done, watching error rates.\n\nOn Mon, 9 Nov 2026 someone wrote:\n> Failing over."
    end

    assert_equal "Failover done, watching error rates.", incident.updates.first.body.to_plain_text
  end

  test "a reply without a status line keeps the current status" do
    incident = Incident.open!(title: "Database failover", body: "Failing over.")
    incident.post_update!(body: "Cause found.", status: "identified")

    reply_to incident, "Still working on it."

    assert incident.reload.identified?
    assert_equal "identified", incident.updates.first.status
    assert_equal "Still working on it.", incident.updates.first.body.to_plain_text
  end

  Incident::STATUSES.each do |status|
    test "a reply starting with status: #{status} sets that status and drops the line" do
      incident = Incident.open!(title: "Database failover", body: "Failing over.")
      incident.update!(status: "identified") if status == "investigating"

      assert_difference -> { incident.updates.count } => 1 do
        reply_to incident, "Status: #{status.upcase}\nFailover done, watching error rates.\n\nOn Mon, 9 Nov 2026 someone wrote:\n> Failing over."
      end

      incident.reload
      assert_equal status, incident.status
      assert_equal status, incident.updates.first.status
      assert_equal "Failover done, watching error rates.", incident.updates.first.body.to_plain_text
      assert_equal (status == "resolved"), incident.resolved_at.present?
    end
  end

  test "a status line with nothing after it keeps a placeholder text" do
    incident = Incident.open!(title: "Database failover", body: "Failing over.")

    reply_to incident, "status: resolved"

    assert incident.reload.resolved?
    assert_equal "(no text)", incident.updates.first.body.to_plain_text
  end

  test "a reply with an unknown status is bounced with the 4 valid ones" do
    incident = Incident.open!(title: "Database failover", body: "Failing over.")
    inbound = nil

    assert_no_difference -> { incident.updates.count } do
      assert_emails 1 do
        inbound = reply_to incident, "status: fixed\nAll good."
      end
    end

    assert inbound.bounced?
    assert incident.reload.investigating?
    bounce_text = ActionMailer::Base.deliveries.last.body.to_s
    assert_includes bounce_text, 'the status "fixed" is not 1 of investigating, identified, monitoring, resolved'
  end

  test "a status line further down is kept as text" do
    incident = Incident.open!(title: "Database failover", body: "Failing over.")

    reply_to incident, "Update below.\nstatus: resolved"

    assert incident.reload.investigating?
    assert_equal "Update below.\nstatus: resolved", incident.updates.first.body.to_plain_text
  end

  test "mail from anyone else is bounced" do
    inbound = nil
    assert_no_difference -> { Incident.count } do
      assert_emails 1 do
        inbound = receive_inbound_email_from_mail \
          to: "incidents@status.example.com", from: "stranger@example.org", subject: "Fake outage", body: "Nothing works!"
      end
    end

    assert inbound.bounced?
    bounce = ActionMailer::Base.deliveries.last
    assert_equal [ "stranger@example.org" ], bounce.to
    assert_includes bounce.body.to_s, "only admins can open or update incidents by e-mail"
  end

  test "a reply to an unknown incident is bounced" do
    inbound = receive_inbound_email_from_mail \
      to: "incident+999999@status.example.com", from: "one@example.com", subject: "Re: x", body: "Update"
    assert inbound.bounced?
  end

  test "HTML-only mail is turned into plain paragraphs" do
    mail = Mail.new do
      to "incidents@status.example.com"
      from "one@example.com"
      subject "CDN errors"
      content_type "text/html; charset=UTF-8"
      body "<p>Images fail to load.</p><script>alert(1)</script>"
    end
    receive_inbound_email_from_source(mail.to_s)

    body = Incident.find_by!(title: "CDN errors").updates.sole.body
    assert_equal "Images fail to load.alert(1)", body.to_plain_text
    assert_not_includes body.to_s, "<script>"
  end

  private
    def reply_to(incident, body)
      receive_inbound_email_from_mail \
        to: "incident+#{incident.id}@status.example.com", from: "two@example.com",
        subject: "Re: #{incident.title}", body:
    end
end
