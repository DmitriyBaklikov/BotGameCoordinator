require "rails_helper"

RSpec.describe GamePreset do
  describe "validations" do
    subject { build(:game_preset) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:sport_type) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:max_participants) }
    it { is_expected.to validate_presence_of(:min_participants) }
    it { is_expected.to validate_presence_of(:visibility) }

    it "validates max_participants is between 2 and 100" do
      preset = build(:game_preset, max_participants: 1)
      expect(preset).not_to be_valid
      preset.max_participants = 101
      expect(preset).not_to be_valid
      preset.max_participants = 50
      expect(preset).to be_valid
    end

    it "validates min_participants is greater than 0" do
      preset = build(:game_preset, min_participants: 0)
      expect(preset).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:organizer).class_name("User") }
    it { is_expected.to belong_to(:location) }
    it { is_expected.to have_many(:game_preset_invitees).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:sport_type).with_values(basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6) }
    it { is_expected.to define_enum_for(:event_type).with_values(game: 0, training: 1) }
    it { is_expected.to define_enum_for(:visibility).with_values(public_game: 0, private_game: 1) }
  end

  describe "custom validations" do
    describe "#preset_limit" do
      let(:organizer) { create(:user, :organizer) }
      let(:location) { create(:location, organizer: organizer) }

      before do
        GamePreset::MAX_PRESETS_PER_ORGANIZER.times do
          create(:game_preset, organizer: organizer, location: location)
        end
      end

      it "prevents creating more than MAX_PRESETS_PER_ORGANIZER presets" do
        preset = build(:game_preset, organizer: organizer, location: location)
        expect(preset).not_to be_valid
        expect(preset.errors[:base]).to include("Preset limit reached (maximum #{GamePreset::MAX_PRESETS_PER_ORGANIZER})")
      end

      it "allows a different organizer to create presets" do
        other_organizer = create(:user, :organizer)
        other_location = create(:location, organizer: other_organizer)
        preset = build(:game_preset, organizer: other_organizer, location: other_location)
        expect(preset).to be_valid
      end
    end
  end
end
