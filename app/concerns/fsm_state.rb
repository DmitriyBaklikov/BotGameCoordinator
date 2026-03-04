module FsmState
  extend ActiveSupport::Concern

  FSM_KEY_PREFIX = "fsm"
  FSM_TTL        = 3600

  def read_fsm_state(user_id)
    if redis_available?
      raw = redis_client.call("GET", fsm_key(user_id))
      raw ? JSON.parse(raw, symbolize_names: true) : nil
    else
      session = UserSession.find_by(user_id: user_id)
      return nil unless session&.state

      { step: session.state, data: (session.data || {}).symbolize_keys }
    end
  rescue StandardError => e
    Rails.logger.error("[FsmState] read error: #{e.message}")
    nil
  end

  def write_fsm_state(user_id, step:, data: {})
    payload = { step: step, data: data }.to_json

    if redis_available?
      redis_client.call("SET", fsm_key(user_id), payload, "EX", FSM_TTL)
    else
      session = UserSession.for_user(user_id)
      session.advance!(step, data)
    end
  rescue StandardError => e
    Rails.logger.error("[FsmState] write error: #{e.message}")
  end

  def clear_fsm_state(user_id)
    if redis_available?
      redis_client.call("DEL", fsm_key(user_id))
    else
      UserSession.find_by(user_id: user_id)&.clear!
    end
  rescue StandardError => e
    Rails.logger.error("[FsmState] clear error: #{e.message}")
  end

  private

  def fsm_key(user_id)
    "#{FSM_KEY_PREFIX}:#{user_id}"
  end

  def redis_client
    @redis_client ||= RedisClient.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  end

  def redis_available?
    return @redis_available unless @redis_available.nil?

    @redis_available = ENV["REDIS_URL"].present? || redis_client.call("PING") == "PONG"
  rescue StandardError
    @redis_available = false
  end
end
