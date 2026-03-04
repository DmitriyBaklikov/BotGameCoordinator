require "rails_helper"

RSpec.describe CheckGameThresholdsJob do
  describe "#perform" do
    let(:game) { create(:game, :expiring_soon, min_participants: 3) }

    before do
      allow(NotificationService).to receive(:notify_cancellation)
    end

    context "when going count is below minimum" do
      before do
        create(:game_participant, game: game, status: :going)
      end

      it "cancels the game" do
        described_class.new.perform
        expect(game.reload).to be_cancelled
      end

      it "notifies participants" do
        described_class.new.perform
        expect(NotificationService).to have_received(:notify_cancellation).with(game)
      end
    end

    context "when going count meets minimum" do
      before do
        create_list(:game_participant, 3, game: game, status: :going)
      end

      it "does not cancel the game" do
        described_class.new.perform
        expect(game.reload).to be_active
      end
    end

    context "when game is not expiring soon" do
      let(:game) { create(:game, scheduled_at: 5.hours.from_now, min_participants: 3) }

      it "does not cancel the game" do
        create(:game_participant, game: game, status: :going)
        described_class.new.perform
        expect(game.reload).to be_active
      end
    end
  end
end
