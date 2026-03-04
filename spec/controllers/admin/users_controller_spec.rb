require "rails_helper"

RSpec.describe Admin::UsersController do
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

  describe "GET #show" do
    it "returns success" do
      user = create(:user)
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH #update" do
    let(:user) { create(:user) }

    it "updates user role" do
      patch :update, params: { id: user.id, user: { role: "organizer" } }
      expect(user.reload).to be_organizer
    end

    it "redirects to show" do
      patch :update, params: { id: user.id, user: { role: "organizer" } }
      expect(response).to redirect_to(admin_user_path(user))
    end
  end
end
