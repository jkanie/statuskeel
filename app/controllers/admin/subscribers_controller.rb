class Admin::SubscribersController < Admin::BaseController
  # ?state=confirmed or ?state=waiting keeps 1 side of the counts at the top. Any other value lists everyone.
  STATES = { "confirmed" => :confirmed, "waiting" => :unconfirmed }.freeze

  def index
    @subscribers = Subscriber.order(created_at: :desc)
    @state = params[:state].to_s if STATES.key?(params[:state].to_s)
    @subscribers = @subscribers.public_send(STATES[@state]) if @state
    # Addresses are stored in lower case, so the search folds the text the same way. % and _ match as written.
    @query = params[:q].to_s.strip
    if @query.present?
      like = "%#{Subscriber.sanitize_sql_like(@query.downcase, "!")}%"
      @subscribers = @subscribers.where("email_address LIKE ? ESCAPE '!'", like)
    end
  end

  def destroy
    Subscriber.find(params[:id]).destroy!
    redirect_to admin_subscribers_path, notice: "Subscriber deleted.", status: :see_other
  end
end
