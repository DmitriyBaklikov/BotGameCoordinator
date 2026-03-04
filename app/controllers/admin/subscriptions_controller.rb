module Admin
  class SubscriptionsController < BaseController
    def index
      @subscriptions = Subscription.includes(:subscriber, :organizer).order(:created_at).page(params[:page])
    end

    def destroy
      @subscription = Subscription.find(params[:id])
      @subscription.destroy!
      redirect_to admin_subscriptions_path, notice: "Subscription removed."
    end
  end
end
