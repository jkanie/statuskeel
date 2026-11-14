class Admin::IncidentsController < Admin::BaseController
  before_action :set_incident, only: %i[show edit update destroy]

  # ?state=unresolved or ?state=resolved keeps 1 side of the counts at the top. Any other value lists every incident.
  STATES = %w[unresolved resolved].freeze

  def index
    @incidents = Incident.newest_first.includes(:uptime_monitor)
    @state = params[:state].to_s if STATES.include?(params[:state].to_s)
    @incidents = @incidents.public_send(@state) if @state
  end

  def show
    @update = @incident.updates.new(status: @incident.status)
  end

  def new
    @incident = Incident.new(impact: :minor, status: :investigating)
  end

  def create
    @incident = Incident.new(incident_params)
    body = params.dig(:incident, :body)

    if body.blank?
      @incident.errors.add(:base, "The first update needs a message")
      render :new, status: :unprocessable_entity
    elsif @incident.valid?
      @incident = Incident.open!(**incident_params.to_h.symbolize_keys, body:)
      redirect_to admin_incident_path(@incident), notice: "Incident opened. Subscribers are being e-mailed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @incident.update(incident_params.except(:status))
      redirect_to admin_incident_path(@incident), notice: "Incident updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @incident.destroy!
    redirect_to admin_incidents_path, notice: "Incident deleted.", status: :see_other
  end

  private
    def set_incident
      @incident = Incident.find(params[:id])
    end

    def incident_params
      params.expect(incident: %i[title impact status uptime_monitor_id])
    end
end
