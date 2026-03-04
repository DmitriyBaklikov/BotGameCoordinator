require "rails_helper"

RSpec.describe UserSession do
  describe "validations" do
    subject { build(:user_session) }

    it { is_expected.to validate_uniqueness_of(:user_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe ".for_user" do
    it "returns existing session" do
      user = create(:user)
      session = create(:user_session, user: user)
      expect(described_class.for_user(user.id)).to eq(session)
    end

    it "initializes new session when none exists" do
      user = create(:user)
      session = described_class.for_user(user.id)
      expect(session).to be_a_new_record
      expect(session.user_id).to eq(user.id)
    end
  end

  describe "#advance!" do
    it "updates state and merges data" do
      session = create(:user_session, state: "step1", data: { "key" => "value" })
      session.advance!("step2", { new_key: "new_value" })
      expect(session.state).to eq("step2")
      expect(session.data).to eq({ "key" => "value", "new_key" => "new_value" })
    end
  end

  describe "#clear!" do
    it "resets state and data" do
      session = create(:user_session, state: "step1", data: { "key" => "value" })
      session.clear!
      expect(session.reload.state).to be_nil
      expect(session.data).to eq({})
    end
  end
end
