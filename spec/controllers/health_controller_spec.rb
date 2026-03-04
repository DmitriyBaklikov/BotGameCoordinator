require "rails_helper"

RSpec.describe HealthController do
  describe "POST #post" do
    it "returns 200 OK" do
      post :post
      expect(response).to have_http_status(:ok)
    end
  end
end
