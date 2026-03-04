require "rails_helper"

RSpec.describe Invitation do
  describe "validations" do
    subject { build(:invitation) }

    it { is_expected.to validate_uniqueness_of(:game_id).scoped_to(:invitee_id) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:inviter).class_name("User") }
    it { is_expected.to belong_to(:invitee).class_name("User") }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, accepted: 1, declined: 2) }
  end
end
