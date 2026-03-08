require "rails_helper"

RSpec.describe ArchiveExpiredGamesJob do
  describe "#perform" do
    it "archives past active games" do
      organizer = create(:user, :organizer)
      location = create(:location, organizer: organizer)
      game = create(:game, organizer: organizer, location: location, status: :active, scheduled_at: 2.days.from_now)
      game.update_column(:scheduled_at, 1.hour.ago) # bypass future validation

      described_class.new.perform
      expect(game.reload).to be_archived
    end

    it "does not archive future active games" do
      game = create(:game, status: :active, scheduled_at: 2.days.from_now)
      described_class.new.perform
      expect(game.reload).to be_active
    end

    it "does not affect cancelled games" do
      organizer = create(:user, :organizer)
      location = create(:location, organizer: organizer)
      game = create(:game, organizer: organizer, location: location, status: :cancelled, scheduled_at: 2.days.from_now)
      game.update_column(:scheduled_at, 1.hour.ago)

      described_class.new.perform
      expect(game.reload).to be_cancelled
    end
  end
end
