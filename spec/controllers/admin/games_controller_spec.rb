require "rails_helper"

RSpec.describe Admin::GamesController do
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
      game = create(:game)
      get :show, params: { id: game.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH #update" do
    let(:game) { create(:game) }

    it "updates game status" do
      patch :update, params: { id: game.id, game: { status: "cancelled" } }
      expect(game.reload).to be_cancelled
    end

    it "redirects to show" do
      patch :update, params: { id: game.id, game: { status: "cancelled" } }
      expect(response).to redirect_to(admin_game_path(game))
    end
  end
end
