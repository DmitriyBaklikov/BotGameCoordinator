require "rails_helper"

RSpec.describe Game do
  describe "validations" do
    subject { build(:game) }

    it { is_expected.to validate_presence_of(:scheduled_at) }
    it { is_expected.to validate_presence_of(:max_participants) }
    it { is_expected.to validate_presence_of(:min_participants) }
    it { is_expected.to validate_presence_of(:sport_type) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:visibility) }

    it "validates title presence" do
      game = build(:game, title: nil, sport_type: nil, event_type: nil)
      expect(game).not_to be_valid
      expect(game.errors[:title]).to be_present
    end

    it "validates max_participants is between 2 and 100" do
      game = build(:game, max_participants: 1)
      expect(game).not_to be_valid
      game.max_participants = 101
      expect(game).not_to be_valid
      game.max_participants = 50
      expect(game).to be_valid
    end

    it "validates min_participants is greater than 0" do
      game = build(:game, min_participants: 0)
      expect(game).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:organizer).class_name("User") }
    it { is_expected.to belong_to(:location) }
    it { is_expected.to have_many(:game_participants).dependent(:destroy) }
    it { is_expected.to have_many(:invitations).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:sport_type).with_values(basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6) }
    it { is_expected.to define_enum_for(:event_type).with_values(game: 0, training: 1) }
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, active: 1, cancelled: 2, archived: 3) }
    it { is_expected.to define_enum_for(:visibility).with_values(public_game: 0, private_game: 1) }
  end

  describe "custom validations" do
    describe "#min_not_greater_than_max" do
      it "is invalid when min > max" do
        game = build(:game, min_participants: 11, max_participants: 10)
        expect(game).not_to be_valid
        expect(game.errors[:min_participants]).to be_present
      end
    end

    describe "#scheduled_at_in_future" do
      it "is invalid when scheduled_at is in the past on create" do
        game = build(:game, scheduled_at: 1.hour.ago)
        expect(game).not_to be_valid
        expect(game.errors[:scheduled_at]).to be_present
      end
    end

    describe "#organizer_active_event_limit" do
      let(:organizer) { create(:user, :organizer) }
      let(:location) { create(:location, organizer: organizer) }

      before do
        2.times do
          create(:game, organizer: organizer, location: location)
        end
      end

      it "prevents creating more than 2 active games" do
        game = build(:game, organizer: organizer, location: location)
        expect(game).not_to be_valid
        expect(game.errors[:base]).to be_present
      end
    end
  end

  describe "#set_title" do
    it "auto-generates title from sport and event type" do
      game = build(:game, title: nil, sport_type: :basketball, event_type: :game)
      game.valid?
      expect(game.title).to eq("Basketball (Game)")
    end

    it "does not overwrite an existing title" do
      game = build(:game, title: "Custom Title")
      game.valid?
      expect(game.title).to eq("Custom Title")
    end
  end

  describe "scopes" do
    let(:organizer) { create(:user, :organizer) }
    let(:location) { create(:location, organizer: organizer) }

    describe ".active_for_organizer" do
      it "returns active games for the organizer" do
        active = create(:game, organizer: organizer, location: location, status: :active)
        create(:game, organizer: organizer, location: location, status: :archived)
        expect(described_class.active_for_organizer(organizer.id)).to eq([active])
      end
    end

    describe ".public_active" do
      it "returns public active future games" do
        game = create(:game, organizer: organizer, location: location, visibility: :public_game, status: :active)
        create(:game, organizer: organizer, location: location, visibility: :private_game, status: :active)
        expect(described_class.public_active).to eq([game])
      end
    end

    describe ".expiring_soon" do
      it "returns active games within 3 hours" do
        soon = create(:game, :expiring_soon, organizer: organizer, location: location)
        create(:game, organizer: organizer, location: location, scheduled_at: 5.hours.from_now)
        expect(described_class.expiring_soon).to eq([soon])
      end
    end
  end

  describe "#at_capacity?" do
    it "returns true when going count equals max" do
      game = create(:game, max_participants: 2, min_participants: 1)
      2.times { create(:game_participant, game: game, user: create(:user), status: :going) }
      expect(game.at_capacity?).to be true
    end

    it "returns false when under capacity" do
      game = create(:game, max_participants: 10)
      create(:game_participant, game: game, status: :going)
      expect(game.at_capacity?).to be false
    end
  end
end
