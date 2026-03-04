require "rails_helper"

RSpec.describe GameParticipant do
  describe "validations" do
    subject { build(:game_participant) }

    it { is_expected.to validate_uniqueness_of(:game_id).scoped_to(:user_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(going: 0, maybe: 1, not_going: 2, reserve: 3) }
  end

  describe "scopes" do
    let(:game) { create(:game) }

    describe ".going" do
      it "returns only going participants" do
        going = create(:game_participant, game: game, status: :going)
        create(:game_participant, game: game, status: :maybe)
        expect(described_class.going).to eq([going])
      end
    end

    describe ".reserve" do
      it "returns only reserve participants" do
        reserve = create(:game_participant, :reserve, game: game)
        create(:game_participant, game: game, status: :going)
        expect(described_class.reserve).to eq([reserve])
      end
    end

    describe ".maybe" do
      it "returns only maybe participants" do
        maybe = create(:game_participant, :maybe, game: game)
        create(:game_participant, game: game, status: :going)
        expect(described_class.maybe).to eq([maybe])
      end
    end
  end
end
