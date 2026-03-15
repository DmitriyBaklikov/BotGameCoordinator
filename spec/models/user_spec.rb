require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:telegram_id) }
    it { is_expected.to validate_uniqueness_of(:telegram_id) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:locale) }
    it { is_expected.to validate_inclusion_of(:locale).in_array(%w[en ru]) }
    it { is_expected.to validate_presence_of(:time_zone) }
    it { is_expected.to validate_inclusion_of(:time_zone).in_array(User::SUPPORTED_TIME_ZONES.keys) }
  end

  describe "associations" do
    it { is_expected.to have_many(:games).with_foreign_key(:organizer_id).dependent(:destroy) }
    it { is_expected.to have_many(:game_participants).dependent(:destroy) }
    it { is_expected.to have_many(:locations).with_foreign_key(:organizer_id).dependent(:destroy) }
    it { is_expected.to have_many(:subscriptions).with_foreign_key(:subscriber_id).dependent(:destroy) }
    it { is_expected.to have_many(:followed_organizers).through(:subscriptions) }
    it { is_expected.to have_many(:invitations).with_foreign_key(:invitee_id).dependent(:destroy) }
    it { is_expected.to have_one(:user_session).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(participant: 0, organizer: 1) }
  end

  describe ".find_or_create_from_telegram" do
    let(:tg_user) do
      OpenStruct.new(
        id: 123_456,
        username: "testuser",
        first_name: "Test",
        last_name: "User",
        language_code: "ru"
      )
    end

    context "when user does not exist" do
      it "creates a new user" do
        expect { described_class.find_or_create_from_telegram(tg_user) }
          .to change(described_class, :count).by(1)
      end

      it "sets attributes from telegram data" do
        user = described_class.find_or_create_from_telegram(tg_user)
        expect(user).to have_attributes(
          telegram_id: 123_456,
          username: "testuser",
          first_name: "Test",
          last_name: "User",
          locale: "ru",
          role: "participant"
        )
      end

      it "defaults locale to en for unsupported languages" do
        tg_user.language_code = "fr"
        user = described_class.find_or_create_from_telegram(tg_user)
        expect(user.locale).to eq("en")
      end
    end

    context "when user already exists" do
      before { create(:user, telegram_id: 123_456) }

      it "returns existing user" do
        expect { described_class.find_or_create_from_telegram(tg_user) }
          .not_to change(described_class, :count)
      end
    end
  end

  describe "#display_name" do
    it "returns first and last name with username" do
      user = build(:user, first_name: "John", last_name: "Doe", username: "johndoe")
      expect(user.display_name).to eq("John Doe (@johndoe)")
    end

    it "returns first name only when last name is nil" do
      user = build(:user, first_name: "John", last_name: nil, username: "johndoe")
      expect(user.display_name).to eq("John (@johndoe)")
    end

    it "falls back to User #id with username when name is nil" do
      user = build(:user, first_name: nil, last_name: nil, username: "johndoe", telegram_id: 100)
      expect(user.display_name).to eq("User #100 (@johndoe)")
    end

    it "falls back to telegram_id" do
      user = build(:user, first_name: nil, last_name: nil, username: nil, telegram_id: 999)
      expect(user.display_name).to eq("User #999")
    end
  end

  describe "#tz" do
    it "returns the ActiveSupport::TimeZone for the user's time_zone" do
      user = build(:user, time_zone: "UTC+03:00")
      expect(user.tz).to be_a(ActiveSupport::TimeZone)
      expect(user.tz.name).to eq("Moscow")
    end

    it "falls back to Moscow for invalid time_zone" do
      user = build(:user)
      user.time_zone = "Invalid"
      # tz should fall back to Moscow
      expect(user.tz.name).to eq("Moscow")
    end
  end

  describe "scopes" do
    describe ".organizers" do
      it "returns only organizers" do
        organizer = create(:user, :organizer)
        create(:user)
        expect(described_class.organizers).to eq([organizer])
      end
    end
  end
end
