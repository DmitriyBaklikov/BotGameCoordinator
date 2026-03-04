require "rails_helper"

RSpec.describe Subscription do
  describe "validations" do
    subject { build(:subscription) }

    it { is_expected.to validate_uniqueness_of(:subscriber_id).scoped_to(:organizer_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:subscriber).class_name("User") }
    it { is_expected.to belong_to(:organizer).class_name("User") }
  end

  describe "#cannot_subscribe_to_self" do
    it "is invalid when subscriber and organizer are the same" do
      user = create(:user, :organizer)
      subscription = build(:subscription, subscriber: user, organizer: user)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:base]).to be_present
    end
  end
end
