require "rails_helper"

RSpec.describe DeepLinkHandler do
  let(:controller) { instance_double("TelegramBotController") }
  let(:game) { create(:game) }
  let(:inviter) { game.organizer }
  let(:invitee) { create(:user) }

  before do
    allow(controller).to receive(:send_message)
    allow(ParticipantManager).to receive(:vote).and_return({ status: :going, message: "Going!" })
  end

  describe ".handle_invite" do
    context "with valid pending invitation" do
      let(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }
      let(:payload) { "invite_#{invitation.token}" }

      it "accepts the invitation" do
        described_class.handle_invite(controller, invitee, payload)
        expect(invitation.reload).to be_accepted
      end

      it "votes the user as going" do
        described_class.handle_invite(controller, invitee, payload)
        expect(ParticipantManager).to have_received(:vote).with(game: game, user: invitee, vote: :going)
      end

      it "sends joined message" do
        described_class.handle_invite(controller, invitee, payload)
        expect(controller).to have_received(:send_message).with(
          invitee.telegram_id,
          I18n.t("bot.deep_link_joined", title: game.title, locale: invitee.locale.to_sym)
        )
      end
    end

    context "with unknown user invitation (backfill invitee_id)" do
      let(:invitation) { create(:invitation, :unknown_user, game: game, inviter: inviter, invitee_username: invitee.username) }
      let(:payload) { "invite_#{invitation.token}" }

      it "backfills invitee_id and accepts" do
        described_class.handle_invite(controller, invitee, payload)
        expect(invitation.reload.invitee_id).to eq(invitee.id)
        expect(invitation.reload).to be_accepted
      end
    end

    context "when game is full" do
      let(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }
      let(:payload) { "invite_#{invitation.token}" }

      before do
        allow(ParticipantManager).to receive(:vote).and_return({ status: :reserve, message: "Reserve" })
      end

      it "sends reserve message" do
        described_class.handle_invite(controller, invitee, payload)
        expect(controller).to have_received(:send_message).with(
          invitee.telegram_id,
          I18n.t("bot.deep_link_reserve", title: game.title, locale: invitee.locale.to_sym)
        )
      end
    end

    context "with invalid token" do
      it "sends invalid link message" do
        described_class.handle_invite(controller, invitee, "invite_bad-token")
        expect(controller).to have_received(:send_message).with(
          invitee.telegram_id,
          I18n.t("bot.deep_link_invalid", locale: invitee.locale.to_sym)
        )
      end
    end

    context "with already accepted invitation" do
      let(:invitation) { create(:invitation, :accepted, game: game, inviter: inviter, invitee: invitee) }
      let(:payload) { "invite_#{invitation.token}" }

      it "sends already used message" do
        described_class.handle_invite(controller, invitee, payload)
        expect(controller).to have_received(:send_message).with(
          invitee.telegram_id,
          I18n.t("bot.deep_link_already_used", locale: invitee.locale.to_sym)
        )
      end
    end

    context "with cancelled game" do
      let(:game) { create(:game, :cancelled) }
      let(:invitation) { create(:invitation, game: game, inviter: inviter, invitee: invitee) }
      let(:payload) { "invite_#{invitation.token}" }

      it "sends game unavailable message" do
        described_class.handle_invite(controller, invitee, payload)
        expect(controller).to have_received(:send_message).with(
          invitee.telegram_id,
          I18n.t("bot.deep_link_game_unavailable", locale: invitee.locale.to_sym)
        )
      end
    end
  end
end
