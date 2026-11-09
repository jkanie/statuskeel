class Admin::IncidentUpdatesController < Admin::BaseController
  def create
    @incident = Incident.find(params[:incident_id])
    attributes = params.expect(incident_update: %i[status body])

    @incident.post_update!(status: attributes[:status], body: attributes[:body])
    redirect_to admin_incident_path(@incident), notice: "Update posted. Subscribers are being e-mailed."
  rescue ActiveRecord::RecordInvalid => error
    @update = @incident.updates.new(attributes)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render "admin/incidents/show", status: :unprocessable_entity
  end
end
