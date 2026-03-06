# Handles health checks and stray POST requests to root (e.g. load balancers, misconfigured webhooks).
# Telegram webhook should be set to the path shown by `bin/rails routes` (telegram_webhook), not "/".
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :post

  def post
    head :ok
  end
end
