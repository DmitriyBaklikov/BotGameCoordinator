class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :post

  def show
    render plain: "ok"
  end

  def post
    head :ok
  end
end
