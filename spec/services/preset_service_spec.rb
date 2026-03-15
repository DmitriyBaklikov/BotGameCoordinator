require "rails_helper"

RSpec.describe PresetService do
  let(:organizer) { create(:user, :organizer) }
  let(:location) { create(:location, organizer: organizer) }
  let(:invitee1) { create(:user, username: "player1") }
  let(:invitee2) { create(:user, username: "player2") }

  describe ".create_from_game_data" do
    let(:game_data) do
      {
        sport_type: "basketball",
        event_type: "game",
        location_id: location.id,
        max_participants: 10,
        min_participants: 4,
        visibility: "public_game"
      }
    end

    it "creates a preset with auto-generated name" do
      preset = PresetService.create_from_game_data(organizer: organizer, game_data: game_data, locale: :en)
      expect(preset).to be_persisted
      expect(preset.name).to include("Basketball")
      expect(preset.sport_type).to eq("basketball")
      expect(preset.location_id).to eq(location.id)
    end

    it "creates a preset with invitees" do
      invitees = [{ user_id: invitee1.id, username: invitee1.username }, { username: "unknown_guy" }]
      preset = PresetService.create_from_game_data(organizer: organizer, game_data: game_data, invitees: invitees, locale: :en)
      expect(preset.game_preset_invitees.count).to eq(2)
      expect(preset.game_preset_invitees.find_by(user_id: invitee1.id)).to be_present
      expect(preset.game_preset_invitees.find_by(username: "unknown_guy")).to be_present
    end
  end

  describe ".auto_name" do
    it "generates name from sport, event type, and location" do
      name = PresetService.auto_name(
        sport_type: "basketball",
        event_type: "game",
        location_name: "Central Court",
        locale: :en
      )
      expect(name).to eq("🏀 Basketball (🎾 Game) / Central Court")
    end
  end

  describe ".build_game_data" do
    it "extracts game creation data from preset" do
      preset = create(:game_preset, organizer: organizer, location: location)
      data = PresetService.build_game_data(preset)
      expect(data[:sport_type]).to eq(preset.sport_type)
      expect(data[:event_type]).to eq(preset.event_type)
      expect(data[:location_id]).to eq(preset.location_id)
      expect(data[:max_participants]).to eq(preset.max_participants)
      expect(data[:min_participants]).to eq(preset.min_participants)
      expect(data[:visibility]).to eq(preset.visibility)
    end
  end

  describe ".delete" do
    it "destroys the preset and its invitees" do
      preset = create(:game_preset, organizer: organizer, location: location)
      create(:game_preset_invitee, game_preset: preset, user: invitee1, username: invitee1.username)

      expect { PresetService.delete(preset) }.to change(GamePreset, :count).by(-1)
        .and change(GamePresetInvitee, :count).by(-1)
    end
  end

  describe ".preset_summary" do
    it "returns formatted summary text" do
      preset = create(:game_preset, organizer: organizer, location: location)
      create(:game_preset_invitee, game_preset: preset, user: invitee1, username: "player1")
      summary = PresetService.preset_summary(preset.reload, locale: :en)
      expect(summary).to include("Basketball")
      expect(summary).to include(location.name)
      expect(summary).to include("@player1")
    end
  end
end
