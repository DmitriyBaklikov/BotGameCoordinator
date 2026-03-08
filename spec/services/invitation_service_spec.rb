require "rails_helper"

RSpec.describe InvitationService do
  let(:game) { create(:game) }
  let(:inviter) { game.organizer }
  let(:invitee) { create(:user) }

  before do
    allow(SendInvitationJob).to receive(:perform_later)
  end

  describe ".create" do
    it "creates an invitation" do
      result = described_class.create(game: game, inviter: inviter, invitee: invitee)
      expect(result[:invitation]).to be_a(Invitation)
      expect(result[:invitation]).to be_pending
    end

    it "enqueues a send invitation job" do
      described_class.create(game: game, inviter: inviter, invitee: invitee)
      expect(SendInvitationJob).to have_received(:perform_later).with(game.id, inviter.id, invitee.id)
    end

    it "returns error when already invited" do
      create(:invitation, game: game, inviter: inviter, invitee: invitee)
      result = described_class.create(game: game, inviter: inviter, invitee: invitee)
      expect(result[:error]).to eq(:already_invited)
    end

    it "returns error when already a participant" do
      create(:game_participant, game: game, user: invitee)
      result = described_class.create(game: game, inviter: inviter, invitee: invitee)
      expect(result[:error]).to eq(:already_participant)
    end
  end

  describe ".accept" do
    let(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }
    let(:controller) { instance_double("TelegramWebhooksController") }

    before do
      allow(controller).to receive(:send_message)
      allow(ParticipantManager).to receive(:vote).and_return({ status: :going, message: "Going!" })
    end

    it "accepts the invitation" do
      described_class.accept(invitation.id, invitee, controller)
      expect(invitation.reload).to be_accepted
    end

    it "votes the user as going" do
      described_class.accept(invitation.id, invitee, controller)
      expect(ParticipantManager).to have_received(:vote).with(game: game, user: invitee, vote: :going)
    end

    it "does nothing for non-pending invitations" do
      invitation.update!(status: :declined)
      described_class.accept(invitation.id, invitee, controller)
      expect(invitation.reload).to be_declined
    end
  end

  describe ".decline" do
    let(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }
    let(:controller) { instance_double("TelegramWebhooksController") }

    before do
      allow(controller).to receive(:send_message)
      allow(NotificationService).to receive(:notify_invite_declined)
    end

    it "declines the invitation" do
      described_class.decline(invitation.id, invitee, controller)
      expect(invitation.reload).to be_declined
    end

    it "notifies the organizer" do
      described_class.decline(invitation.id, invitee, controller)
      expect(NotificationService).to have_received(:notify_invite_declined).with(inviter, invitee, game)
    end
  end
end
