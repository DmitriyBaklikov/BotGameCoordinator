# frozen_string_literal: true

require "rails_helper"

RSpec.describe FsmState do
  let(:test_class) do
    Class.new do
      include FsmState

      attr_accessor :bot

      def initialize(bot: nil)
        @bot = bot
      end
    end
  end

  let(:bot) { instance_double(Telegram::Bot::Client) }
  let(:instance) { test_class.new(bot: bot) }
  let(:user) { create(:user) }

  before do
    # Force DB fallback (no Redis in tests)
    allow(instance).to receive(:redis_available?).and_return(false)
  end

  describe "#track_message" do
    it "appends message_id to FSM state" do
      instance.write_fsm_state(user.id, step: "sport_type", data: {})
      instance.track_message(user.id, message_id: 101, chat_id: 999)
      instance.track_message(user.id, message_id: 102, chat_id: 999)

      state = instance.read_fsm_state(user.id)
      expect(state[:message_ids]).to eq([101, 102])
      expect(state[:chat_id]).to eq(999)
    end

    it "does nothing when no FSM state exists" do
      expect { instance.track_message(user.id, message_id: 101, chat_id: 999) }.not_to raise_error
    end
  end

  describe "#delete_fsm_messages" do
    it "calls bot.delete_message for each tracked message_id in reverse order" do
      instance.write_fsm_state(user.id, step: "sport_type", data: {})
      instance.track_message(user.id, message_id: 101, chat_id: 999)
      instance.track_message(user.id, message_id: 102, chat_id: 999)

      deleted = []
      allow(bot).to receive(:delete_message) { |args| deleted << args[:message_id] }

      instance.delete_fsm_messages(user.id)

      expect(deleted).to eq([102, 101])
    end

    it "silently ignores Telegram API errors" do
      instance.write_fsm_state(user.id, step: "sport_type", data: {})
      instance.track_message(user.id, message_id: 101, chat_id: 999)

      allow(bot).to receive(:delete_message).and_raise(Telegram::Bot::Error, "message not found")

      expect { instance.delete_fsm_messages(user.id) }.not_to raise_error
    end

    it "does nothing when no message_ids tracked" do
      instance.write_fsm_state(user.id, step: "sport_type", data: {})

      expect { instance.delete_fsm_messages(user.id) }.not_to raise_error
      expect(bot).not_to have_received(:delete_message) if bot.respond_to?(:delete_message)
    end
  end

  describe "#clear_fsm_state" do
    it "deletes tracked messages before clearing state" do
      instance.write_fsm_state(user.id, step: "sport_type", data: {})
      instance.track_message(user.id, message_id: 101, chat_id: 999)

      allow(bot).to receive(:delete_message)

      instance.clear_fsm_state(user.id)

      expect(bot).to have_received(:delete_message).with(chat_id: 999, message_id: 101)
      expect(instance.read_fsm_state(user.id)).to be_nil
    end
  end
end
