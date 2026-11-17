class Admin::MonitorsController < Admin::BaseController
  before_action :set_monitor, only: %i[show edit update destroy check]

  # ?state=up, down or pending keeps the active monitors in that state, and ?state=paused the paused ones, as the
  # counts at the top give them. Any other value lists every monitor.
  STATES = %w[up down pending paused].freeze

  def index
    @counts = UptimeMonitor.active.group(:status).count.merge("paused" => UptimeMonitor.paused.count)
    @state = params[:state].to_s if STATES.include?(params[:state].to_s)
    @monitors = UptimeMonitor.ordered
    if @state == "paused"
      @monitors = @monitors.paused
    elsif @state
      @monitors = @monitors.active.where(status: @state)
    end
    # ?q= keeps the monitors whose name or URL holds the text, in any case, as the subscriber search does.
    @query = params[:q].to_s.strip
    if @query.present?
      like = "%#{UptimeMonitor.sanitize_sql_like(@query.downcase, "!")}%"
      @monitors = @monitors.where("LOWER(name) LIKE :like ESCAPE '!' OR LOWER(url) LIKE :like ESCAPE '!'", like:)
    end
  end

  def show
    # ?result=down keeps the failed checks, such as to read the errors of a monitor that fails now and then.
    @failed_only = params[:result] == "down"
    @checks = (@failed_only ? @monitor.checks.failed : @monitor.checks).recent.limit(50)
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

  # Queues a check of every active monitor at once, such as after a deploy. A paused monitor stays paused.
  def check_all
    monitors = UptimeMonitor.active.to_a
    monitors.each { |monitor| CheckMonitorJob.perform_later(monitor) }
    redirect_to admin_monitors_path, notice: "#{helpers.pluralize(monitors.size, "check")} queued."
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
