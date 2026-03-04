require "rails_helper"

RSpec.describe NotifySubscribersJob do
  let(:organizer) { create(:user, :organizer) }
  let(:game) { create(:game, organizer: organizer, visibility: :public_game, status: :active) }

  before do
    allow(NotificationService).to receive(:notify_new_game)
  end

  describe "#perform" do
    context "with subscribers" do
      let!(:subscriber) { create(:user) }

      before do
        create(:subscription, subscriber: subscriber, organizer: organizer)
      end

      it "notifies each subscriber" do
        described_class.new.perform(game.id)
        expect(NotificationService).to have_received(:notify_new_game).with(subscriber, game)
      end
    end

    context "with no subscribers" do
      it "does nothing" do
        described_class.new.perform(game.id)
        expect(NotificationService).not_to have_received(:notify_new_game)
      end
    end

    context "with private game" do
      let(:game) { create(:game, organizer: organizer, visibility: :private_game) }

      it "does not notify" do
        create(:subscription, subscriber: create(:user), organizer: organizer)
        described_class.new.perform(game.id)
        expect(NotificationService).not_to have_received(:notify_new_game)
      end
    end

    context "when game does not exist" do
      it "does nothing" do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end
  end
end
