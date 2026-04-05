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

      session_data = session.data || {}
      result = { step: session.state, data: session_data.except("message_ids", "chat_id").symbolize_keys }
      result[:message_ids] = session_data["message_ids"] if session_data["message_ids"]
      result[:chat_id] = session_data["chat_id"] if session_data["chat_id"]
      result
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

  def track_message(user_id, message_id:, chat_id:)
    if redis_available?
      raw = redis_client.call("GET", fsm_key(user_id))
      return unless raw

      state = JSON.parse(raw, symbolize_names: true)
      state[:message_ids] ||= []
      state[:message_ids] << message_id
      state[:chat_id] = chat_id
      redis_client.call("SET", fsm_key(user_id), state.to_json, "EX", FSM_TTL)
    else
      session = UserSession.find_by(user_id: user_id)
      return unless session&.state

      ids = session.data&.dig("message_ids") || []
      ids << message_id
      session.update!(data: (session.data || {}).merge("message_ids" => ids, "chat_id" => chat_id))
    end
  rescue StandardError => e
    Rails.logger.error("[FsmState] track_message error: #{e.message}")
  end

  def delete_fsm_messages(user_id)
    state = read_fsm_state(user_id)
    return unless state

    chat_id = state[:chat_id]
    message_ids = state[:message_ids]
    return unless chat_id && message_ids&.any?

    message_ids.reverse_each do |mid|
      bot.delete_message(chat_id: chat_id, message_id: mid)
    rescue StandardError => e
      Rails.logger.debug("[FsmState] delete_message failed for #{mid}: #{e.message}")
    end
  rescue StandardError => e
    Rails.logger.debug("[FsmState] delete_fsm_messages error: #{e.message}")
  end

  def clear_fsm_state(user_id)
    delete_fsm_messages(user_id)

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
