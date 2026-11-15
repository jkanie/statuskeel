class Admin::SubscribersController < Admin::BaseController
  # ?state=confirmed or ?state=waiting keeps 1 side of the counts at the top. Any other value lists everyone.
  STATES = { "confirmed" => :confirmed, "waiting" => :unconfirmed }.freeze

  def index
    # The newest 1st. The id breaks a tie, such that the screen and the CSV keep 1 order.
    @subscribers = Subscriber.order(created_at: :desc, id: :desc)
    @state = params[:state].to_s if STATES.key?(params[:state].to_s)
    @subscribers = @subscribers.public_send(STATES[@state]) if @state
    # Addresses are stored in lower case, so the search folds the text the same way. % and _ match as written.
    @query = params[:q].to_s.strip
    if @query.present?
      like = "%#{Subscriber.sanitize_sql_like(@query.downcase, "!")}%"
      @subscribers = @subscribers.where("email_address LIKE ? ESCAPE '!'", like)
    end
    respond_to do |format|
      format.html
      format.csv do
        send_data csv(@subscribers), type: :csv,
                                     filename: "subscribers-#{Time.current.utc.to_date.iso8601}.csv"
      end
    end
  end

  def destroy
    Subscriber.find(params[:id]).destroy!
    redirect_to admin_subscribers_path, notice: "Subscriber deleted.", status: :see_other
  end

  private
    # 1 row per address, in the list's order, times in UTC (ISO 8601). URI::MailTo::EMAIL_REGEXP allows no comma,
    # no double quote, no line break in an address, so no field needs quotes.
    def csv(subscribers)
      rows = subscribers.map do |subscriber|
        [ subscriber.email_address, subscriber.confirmed_at&.utc&.iso8601, subscriber.created_at.utc.iso8601 ].join(",")
      end
      [ "email_address,confirmed_at,subscribed_at", *rows ].join("\n") + "\n"
    end
end
