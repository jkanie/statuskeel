class Admin::SubscribersController < Admin::BaseController
  def index
    @subscribers = Subscriber.order(created_at: :desc)
  end

  def destroy
    Subscriber.find(params[:id]).destroy!
    redirect_to admin_subscribers_path, notice: "Subscriber deleted.", status: :see_other
  end
end
