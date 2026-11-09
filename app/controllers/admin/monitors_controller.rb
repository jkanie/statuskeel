class Admin::MonitorsController < Admin::BaseController
  before_action :set_monitor, only: %i[show edit update destroy check]

  def index
    @monitors = UptimeMonitor.ordered
  end

  def show
    @checks = @monitor.checks.recent.limit(50)
    @history = @monitor.history
  end

  def new
    @monitor = UptimeMonitor.new
  end

  def create
    @monitor = UptimeMonitor.new(monitor_params)

    if @monitor.save
      redirect_to admin_monitor_path(@monitor), notice: "Monitor created. The first check runs within a minute."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @monitor.update(monitor_params)
      redirect_to admin_monitor_path(@monitor), notice: "Monitor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @monitor.destroy!
    redirect_to admin_monitors_path, notice: "Monitor deleted.", status: :see_other
  end

  def check
    CheckMonitorJob.perform_later(@monitor)
    redirect_to admin_monitor_path(@monitor), notice: "Check queued."
  end

  private
    def set_monitor
      @monitor = UptimeMonitor.find(params[:id])
    end

    def monitor_params
      params.expect(uptime_monitor: %i[name url interval_seconds timeout_seconds expected_status_min
                                       expected_status_max keyword failure_threshold active])
    end
end
