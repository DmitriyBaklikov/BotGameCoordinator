require "rails_helper"

RSpec.describe SendInvitationJob do
  let(:game) { create(:game) }
  let(:inviter) { game.organizer }
  let(:invitee) { create(:user) }

  before do
    allow(NotificationService).to receive(:send_invitation_dm)
  end

  describe "#perform" do
    it "creates an invitation and sends DM" do
      described_class.new.perform(game.id, inviter.id, invitee.id)
      expect(Invitation.find_by(game: game, invitee: invitee)).to be_pending
      expect(NotificationService).to have_received(:send_invitation_dm)
    end

    it "does nothing when game does not exist" do
      described_class.new.perform(0, inviter.id, invitee.id)
      expect(NotificationService).not_to have_received(:send_invitation_dm)
    end

    it "does nothing when inviter does not exist" do
      described_class.new.perform(game.id, 0, invitee.id)
      expect(NotificationService).not_to have_received(:send_invitation_dm)
    end

    it "does nothing when invitee does not exist" do
      described_class.new.perform(game.id, inviter.id, 0)
      expect(NotificationService).not_to have_received(:send_invitation_dm)
    end
  end
end
