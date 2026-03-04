require "rails_helper"

RSpec.describe Location do
  describe "validations" do
    subject { build(:location) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organizer_id).case_insensitive }
  end

  describe "associations" do
    it { is_expected.to belong_to(:organizer).class_name("User") }
    it { is_expected.to have_many(:games).dependent(:restrict_with_error) }
  end
end
