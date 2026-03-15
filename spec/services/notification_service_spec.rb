require "rails_helper"

RSpec.describe NotificationService do
  let(:bot_instance) { instance_double(Telegram::Bot::Client) }

  before do
    allow(described_class).to receive(:send_dm) # rubocop:disable RSpec/SubjectStub
    allow(described_class).to receive(:bot_instance).and_return(bot_instance) # rubocop:disable RSpec/SubjectStub
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

    it "returns true on success" do
      allow(bot_instance).to receive(:send_message).and_return(true)
      result = described_class.send_invitation_dm(invitee, game, invitation)
      expect(result).to be true
      expect(bot_instance).to have_received(:send_message).with(
        hash_including(chat_id: invitee.telegram_id, parse_mode: "HTML")
      )
    end

    it "returns false on Telegram API error" do
      allow(bot_instance).to receive(:send_message)
        .and_raise(Telegram::Bot::Forbidden.new("Forbidden: bot was blocked by the user"))
      result = described_class.send_invitation_dm(invitee, game, invitation)
      expect(result).to be false
    end
  end

  describe ".notify_inviter_dm_sent" do
    let(:inviter) { create(:user) }
    let(:invitee) { create(:user) }

    it "sends DM to inviter about successful delivery" do
      described_class.notify_inviter_dm_sent(inviter, invitee)
      expect(described_class).to have_received(:send_dm).with( # rubocop:disable RSpec/SubjectStub
        inviter.telegram_id,
        I18n.t("bot.invitation_sent_dm", name: invitee.display_name, locale: inviter.locale.to_sym)
      )
    end
  end

  describe ".notify_inviter_deep_link" do
    let(:inviter) { create(:user) }
    let(:link) { "https://t.me/bot?start=inv_abc123" }
    let(:invitee_name) { "John" }

    it "sends DM to inviter with deep link" do
      described_class.notify_inviter_deep_link(inviter, invitee_name, link)
      expect(described_class).to have_received(:send_dm).with( # rubocop:disable RSpec/SubjectStub
        inviter.telegram_id,
        I18n.t("bot.invitation_sent_link", name: invitee_name, link: link, locale: inviter.locale.to_sym)
      )
    end
  end
end
