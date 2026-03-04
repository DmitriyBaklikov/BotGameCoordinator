require "rails_helper"

RSpec.describe ReservePromotionJob do
  let(:game) { create(:game, max_participants: 2, min_participants: 1) }

  before do
    allow(NotificationService).to receive(:notify_reserve_promotion)
  end

  describe "#perform" do
    context "when there is a reserve participant and spots available" do
      let(:reserve_user) { create(:user) }

      before do
        create(:game_participant, game: game, user: create(:user), status: :going)
        create(:game_participant, :reserve, game: game, user: reserve_user, notified_reserve: false)
      end

      it "marks the reserve participant as notified" do
        described_class.new.perform(game.id)
        expect(game.game_participants.find_by(user: reserve_user).notified_reserve).to be true
      end

      it "notifies the reserve participant" do
        described_class.new.perform(game.id)
        expect(NotificationService).to have_received(:notify_reserve_promotion).with(reserve_user, game)
      end
    end

    context "when reserve participant already notified" do
      before do
        create(:game_participant, :reserve, game: game, user: create(:user), notified_reserve: true)
      end

      it "does not notify again" do
        described_class.new.perform(game.id)
        expect(NotificationService).not_to have_received(:notify_reserve_promotion)
      end
    end

    context "when game is at capacity" do
      before do
        2.times { create(:game_participant, game: game, user: create(:user), status: :going) }
        create(:game_participant, :reserve, game: game, user: create(:user))
      end

      it "does not notify reserve" do
        described_class.new.perform(game.id)
        expect(NotificationService).not_to have_received(:notify_reserve_promotion)
      end
    end

    context "when game is not active" do
      let(:game) { create(:game, :cancelled, min_participants: 1) }

      it "does nothing" do
        create(:game_participant, :reserve, game: game, user: create(:user))
        described_class.new.perform(game.id)
        expect(NotificationService).not_to have_received(:notify_reserve_promotion)
      end
    end

    context "when game does not exist" do
      it "does nothing" do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end
  end
end
