require "rails_helper"

RSpec.describe Invitation do
  describe "validations" do
    subject { build(:invitation) }

    it { is_expected.to validate_uniqueness_of(:game_id).scoped_to(:invitee_id) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_uniqueness_of(:token) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:inviter).class_name("User") }
    it { is_expected.to belong_to(:invitee).class_name("User").optional }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, accepted: 1, declined: 2) }
  end

  describe "token generation" do
    it "auto-generates a UUID token on create" do
      invitation = create(:invitation)
      expect(invitation.token).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "does not overwrite an already-set token" do
      invitation = create(:invitation, token: "custom-token")
      expect(invitation.token).to eq("custom-token")
    end
  end

  describe "invitee optionality" do
    it "allows invitee to be nil" do
      invitation = build(:invitation, :unknown_user)
      expect(invitation).to be_valid
    end

    it "creates invitation with invitee: nil and invitee_username set" do
      invitation = create(:invitation, invitee: nil, invitee_username: "john")
      expect(invitation).to be_persisted
      expect(invitation.invitee).to be_nil
      expect(invitation.invitee_username).to eq("john")
    end
  end

  describe "#valid_for_deep_link?" do
    it "returns true for pending invitation with active future game" do
      invitation = create(:invitation)
      expect(invitation.valid_for_deep_link?).to be true
    end

    it "returns false for accepted invitation" do
      invitation = create(:invitation, :accepted)
      expect(invitation.valid_for_deep_link?).to be false
    end

    it "returns false for cancelled game" do
      game = create(:game, :cancelled)
      invitation = create(:invitation, game: game)
      expect(invitation.valid_for_deep_link?).to be false
    end

    it "returns false for past game" do
      game = create(:game)
      game.update_column(:scheduled_at, 1.hour.ago)
      invitation = create(:invitation, game: game)
      expect(invitation.valid_for_deep_link?).to be false
    end
  end
end
