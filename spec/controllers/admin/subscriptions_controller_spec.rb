require "rails_helper"

RSpec.describe Admin::SubscriptionsController do
  before do
    request.env["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic
      .encode_credentials("admin", "changeme")
  end

  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE #destroy" do
    it "removes the subscription" do
      subscription = create(:subscription)
      expect {
        delete :destroy, params: { id: subscription.id }
      }.to change(Subscription, :count).by(-1)
    end

    it "redirects to index" do
      subscription = create(:subscription)
      delete :destroy, params: { id: subscription.id }
      expect(response).to redirect_to(admin_subscriptions_path)
    end
  end
end
