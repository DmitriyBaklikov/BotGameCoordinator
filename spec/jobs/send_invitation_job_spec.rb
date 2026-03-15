require "rails_helper"

RSpec.describe SendInvitationJob do
  let(:game) { create(:game) }
  let(:inviter) { game.organizer }
  let(:invitee) { create(:user) }

  before do
    allow(NotificationService).to receive(:send_invitation_dm).and_return(true)
    allow(NotificationService).to receive(:notify_inviter_dm_sent)
    allow(NotificationService).to receive(:notify_inviter_deep_link)
    allow(Rails.application.config).to receive(:telegram_bot_username).and_return("testbot")
  end

  describe "#perform" do
    context "when invitee_id is provided (known user)" do
      let!(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }

      it "sends DM to invitee" do
        described_class.new.perform(game.id, inviter.id, invitee.id)
        expect(NotificationService).to have_received(:send_invitation_dm)
      end

      it "notifies inviter of successful DM" do
        described_class.new.perform(game.id, inviter.id, invitee.id)
        expect(NotificationService).to have_received(:notify_inviter_dm_sent).with(inviter, invitee)
      end

      context "when DM fails" do
        before do
          allow(NotificationService).to receive(:send_invitation_dm).and_return(false)
        end

        it "sends deep link to inviter" do
          described_class.new.perform(game.id, inviter.id, invitee.id)
          expect(NotificationService).to have_received(:notify_inviter_deep_link).with(
            inviter,
            invitee.display_name,
            a_string_matching(%r{https://t\.me/testbot\?start=invite_})
          )
        end
      end
    end

    context "when invitation_id is provided (unknown user)" do
      let(:invitation) { create(:invitation, :unknown_user, game: game, inviter: inviter) }

      it "sends deep link to inviter immediately" do
        described_class.new.perform(game.id, inviter.id, nil, invitation.id)
        expect(NotificationService).to have_received(:notify_inviter_deep_link).with(
          inviter,
          "@unknown_user",
          a_string_matching(%r{https://t\.me/testbot\?start=invite_})
        )
        expect(NotificationService).not_to have_received(:send_invitation_dm)
      end
    end

    it "does nothing when game does not exist" do
      described_class.new.perform(0, inviter.id, invitee.id)
      expect(NotificationService).not_to have_received(:send_invitation_dm)
    end

    it "does nothing when inviter does not exist" do
      described_class.new.perform(game.id, 0, invitee.id)
      expect(NotificationService).not_to have_received(:send_invitation_dm)
    end
  end
end
