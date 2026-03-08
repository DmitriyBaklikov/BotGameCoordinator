require "rails_helper"

RSpec.describe NotificationService do
  before do
    allow(described_class).to receive(:send_dm) # rubocop:disable RSpec/SubjectStub
  end

  describe ".notify_cancellation" do
    let(:game) { create(:game) }
    let!(:participant) { create(:game_participant, game: game, status: :going) }

    it "sends DM to going participants and organizer" do
      described_class.notify_cancellation(game)
      expect(described_class).to have_received(:send_dm).at_least(:twice) # rubocop:disable RSpec/SubjectStub
    end
  end

  describe ".notify_removal" do
    let(:game) { create(:game) }
    let(:user) { create(:user) }

    it "sends removal notification" do
      described_class.notify_removal(user, game)
      expect(described_class).to have_received(:send_dm).once # rubocop:disable RSpec/SubjectStub
    end
  end

  describe ".notify_reserve_promotion" do
    let(:game) { create(:game) }
    let(:user) { create(:user) }

    it "sends reserve promotion notification" do
      described_class.notify_reserve_promotion(user, game)
      expect(described_class).to have_received(:send_dm).once # rubocop:disable RSpec/SubjectStub
    end
  end

  describe ".notify_new_game" do
    let(:game) { create(:game) }
    let(:user) { create(:user) }

    it "sends new game notification" do
      described_class.notify_new_game(user, game)
      expect(described_class).to have_received(:send_dm).once # rubocop:disable RSpec/SubjectStub
    end
  end

  describe ".notify_invite_declined" do
    let(:game) { create(:game) }
    let(:organizer) { game.organizer }
    let(:invitee) { create(:user) }

    it "sends decline notification to organizer" do
      described_class.notify_invite_declined(organizer, invitee, game)
      expect(described_class).to have_received(:send_dm).once # rubocop:disable RSpec/SubjectStub
    end
  end

  describe ".send_invitation_dm" do
    let(:game) { create(:game) }
    let(:invitee) { create(:user) }
    let(:invitation) { create(:invitation, game: game, invitee: invitee) }

    it "sends invitation DM" do
      described_class.send_invitation_dm(invitee, game, invitation)
      expect(described_class).to have_received(:send_dm).once # rubocop:disable RSpec/SubjectStub
    end
  end
end
