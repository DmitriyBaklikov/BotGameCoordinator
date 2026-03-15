require "rails_helper"

RSpec.describe GamePresetInvitee do
  describe "associations" do
    it { is_expected.to belong_to(:game_preset) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe "factory" do
    it "creates a valid game_preset_invitee" do
      invitee = build(:game_preset_invitee)
      expect(invitee).to be_valid
    end

    it "creates a valid invitee with unknown_user trait" do
      invitee = build(:game_preset_invitee, :unknown_user)
      expect(invitee).to be_valid
      expect(invitee.user).to be_nil
      expect(invitee.username).to eq("unknown_user")
    end
  end
end
