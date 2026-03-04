require "rails_helper"

RSpec.describe ParticipantManager do
  let(:game) { create(:game, max_participants: 3, min_participants: 2) }
  let(:user) { create(:user) }

  before do
    allow(ReservePromotionJob).to receive(:perform_later)
  end

  describe ".vote" do
    context "when voting :going" do
      it "creates a going participant" do
        result = described_class.vote(game: game, user: user, vote: :going)
        expect(result[:status]).to eq(:going)
        expect(game.game_participants.going.count).to eq(1)
      end

      it "adds to reserve when at capacity" do
        3.times { create(:game_participant, game: game, user: create(:user), status: :going) }
        game.reload
        result = described_class.vote(game: game, user: user, vote: :going)
        expect(result[:status]).to eq(:reserve)
      end
    end

    context "when voting :maybe" do
      it "creates a maybe participant" do
        result = described_class.vote(game: game, user: user, vote: :maybe)
        expect(result[:status]).to eq(:maybe)
      end
    end

    context "when voting :not_going" do
      it "creates a not_going participant" do
        result = described_class.vote(game: game, user: user, vote: :not_going)
        expect(result[:status]).to eq(:not_going)
      end
    end

    context "when changing from going to not_going" do
      before { create(:game_participant, game: game, user: user, status: :going) }

      it "triggers reserve promotion" do
        described_class.vote(game: game, user: user, vote: :not_going)
        expect(ReservePromotionJob).to have_received(:perform_later).with(game.id)
      end
    end

    context "when changing from maybe to going" do
      before { create(:game_participant, game: game, user: user, status: :maybe) }

      it "does not trigger reserve promotion" do
        described_class.vote(game: game, user: user, vote: :going)
        expect(ReservePromotionJob).not_to have_received(:perform_later)
      end
    end
  end

  describe ".remove" do
    let(:organizer) { game.organizer }
    let(:participant) { create(:user) }

    before do
      create(:game_participant, game: game, user: participant, status: :going)
      allow(NotificationService).to receive(:notify_removal)
    end

    it "removes the participant" do
      described_class.remove(game: game, user: participant, remover: organizer)
      expect(game.game_participants.find_by(user: participant)).to be_nil
    end

    it "notifies the removed user" do
      described_class.remove(game: game, user: participant, remover: organizer)
      expect(NotificationService).to have_received(:notify_removal).with(participant, game)
    end

    it "triggers reserve promotion" do
      described_class.remove(game: game, user: participant, remover: organizer)
      expect(ReservePromotionJob).to have_received(:perform_later).with(game.id)
    end

    it "does nothing when remover is not the organizer" do
      other_user = create(:user)
      described_class.remove(game: game, user: participant, remover: other_user)
      expect(game.game_participants.find_by(user: participant)).to be_present
    end
  end

  describe ".confirm_reserve" do
    let(:reserve_user) { create(:user) }

    before do
      create(:game_participant, :reserve, game: game, user: reserve_user)
    end

    it "promotes reserve to going when spots available" do
      described_class.confirm_reserve(game_id: game.id, user: reserve_user)
      expect(game.game_participants.find_by(user: reserve_user).status).to eq("going")
    end

    it "does not promote when game is at capacity" do
      3.times { create(:game_participant, game: game, user: create(:user), status: :going) }
      described_class.confirm_reserve(game_id: game.id, user: reserve_user)
      expect(game.game_participants.find_by(user: reserve_user).status).to eq("reserve")
    end

    it "does nothing for non-existent games" do
      expect(described_class.confirm_reserve(game_id: 0, user: reserve_user)).to be_nil
    end
  end
end
