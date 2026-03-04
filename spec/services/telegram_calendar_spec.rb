require "rails_helper"

RSpec.describe TelegramCalendar do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2026, 3, 15, 14, 20) }
  after  { travel_back }

  def btn_texts(rows)
    rows.flatten.map { |b| b[:text] }
  end

  describe ".start" do
    it "returns text and year-selection keyboard" do
      result = described_class.start(locale: :en)

      expect(result[:text]).to eq("📅 Select date and time:")
      expect(result[:keyboard]).to be_a(Telegram::Bot::Types::InlineKeyboardMarkup)

      buttons = result[:keyboard].inline_keyboard.flatten
      expect(buttons.map { |b| b[:text] }).to eq(%w[2026 2027])
      expect(buttons.first[:callback_data]).to eq("cal:sy:2026:0:0:0:0")
    end

    it "returns Russian text when locale is :ru" do
      result = described_class.start(locale: :ru)
      expect(result[:text]).to eq("📅 Выберите дату и время:")
    end
  end

  describe ".process" do
    describe "year selection (sy)" do
      it "returns month keyboard for selected year" do
        parts = %w[cal sy 2026 0 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("2026")
        expect(result[:keyboard]).to be_a(Telegram::Bot::Types::InlineKeyboardMarkup)

        rows = result[:keyboard].inline_keyboard
        # 3 rows of months + 1 back button row
        expect(rows.size).to eq(4)

        # Past months (Jan, Feb) should be dimmed
        first_row = rows[0].map { |b| b[:text] }
        expect(first_row[0]).to eq("·") # Jan
        expect(first_row[1]).to eq("·") # Feb
        expect(first_row[2]).to eq("Mar") # current month
        expect(first_row[3]).to eq("Apr")
      end
    end

    describe "month selection (sm)" do
      it "returns day calendar keyboard" do
        parts = %w[cal sm 2026 3 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("March 2026")
        rows = result[:keyboard].inline_keyboard

        # Navigation row + weekday headers + weeks + back button
        expect(rows.size).to be >= 4

        # Check weekday headers
        headers = rows[1].map { |b| b[:text] }
        expect(headers).to eq(%w[Mo Tu We Th Fr Sa Su])

        # Check navigation row has month name
        nav_row = rows[0].map { |b| b[:text] }
        expect(nav_row).to include("March 2026")
      end

      it "dims past days" do
        parts = %w[cal sm 2026 3 0 0 0]
        result = described_class.process(parts, locale: :en)

        rows = result[:keyboard].inline_keyboard
        day_rows = rows[2..-2]
        all_buttons = day_rows.flatten

        day_buttons = all_buttons.reject { |b| b[:text].strip.empty? }
        past_days = day_buttons.select { |b| b[:text] == "·" }
        future_days = day_buttons.select { |b| b[:text].match?(/^\d+$/) }

        expect(past_days.size).to eq(14) # days 1-14 are past
        expect(future_days.map { |b| b[:text].to_i }).to include(15, 16, 31)
      end
    end

    describe "day selection (sd)" do
      it "returns hour keyboard" do
        parts = %w[cal sd 2026 3 20 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("20 March 2026")
        rows = result[:keyboard].inline_keyboard

        # 4 rows of 6 hours + 1 back button
        expect(rows.size).to eq(5)

        # All hours should be selectable for a future day
        hour_buttons = rows[0..3].flatten
        selectable = hour_buttons.select { |b| b[:text].match?(/^\d+$/) }
        expect(selectable.size).to eq(24)
      end

      it "dims hours within the minimum lead time when selecting today" do
        parts = %w[cal sd 2026 3 15 0 0]
        result = described_class.process(parts, locale: :en)

        rows = result[:keyboard].inline_keyboard
        hour_buttons = rows[0..3].flatten

        # Cutoff is 16:20 (14:20 + 2h), so hours 0-15 should be dimmed
        dimmed = hour_buttons.select { |b| b[:text] == "·" }
        expect(dimmed.size).to eq(16)

        # Hour 16 should be selectable (still has future minute slots)
        hour_16 = hour_buttons.find { |b| b[:text] == "16" }
        expect(hour_16).not_to be_nil
        expect(hour_16[:callback_data]).to include("sh:")
      end
    end

    describe "hour selection (sh)" do
      it "returns minute keyboard" do
        parts = %w[cal sh 2026 3 20 18 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("18:__")
        rows = result[:keyboard].inline_keyboard

        # 1 row of minute options + 1 back button
        expect(rows.size).to eq(2)

        minute_buttons = rows[0]
        expect(minute_buttons.map { |b| b[:text] }).to eq(%w[18:00 18:15 18:30 18:45])
      end

      it "dims minutes within the minimum lead time for cutoff hour" do
        # Cutoff is 16:20 (14:20 + 2h), so for hour 16:
        parts = %w[cal sh 2026 3 15 16 0]
        result = described_class.process(parts, locale: :en)

        rows = result[:keyboard].inline_keyboard
        minute_buttons = rows[0]

        # 16:00 and 16:15 should be dimmed (cutoff is 16:20)
        expect(minute_buttons[0][:text]).to eq("·")  # 16:00
        expect(minute_buttons[1][:text]).to eq("·")  # 16:15
        expect(minute_buttons[2][:text]).to eq("16:30")
        expect(minute_buttons[3][:text]).to eq("16:45")
      end
    end

    describe "minute selection (si)" do
      it "returns completed datetime" do
        parts = %w[cal si 2026 3 20 18 30]
        result = described_class.process(parts, locale: :en)

        expect(result[:datetime]).to eq(Time.zone.local(2026, 3, 20, 18, 30))
      end
    end

    describe "month navigation (pm/nm)" do
      it "navigates to previous month" do
        parts = %w[cal pm 2026 3 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("March 2026")
        expect(result[:keyboard]).to be_a(Telegram::Bot::Types::InlineKeyboardMarkup)
      end

      it "navigates to next month" do
        parts = %w[cal nm 2026 4 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("April 2026")
      end
    end

    describe "back navigation" do
      it "by -> returns to year selection" do
        parts = %w[cal by 2026 0 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to eq("📅 Select date and time:")
        buttons = result[:keyboard].inline_keyboard.flatten
        expect(buttons.map { |b| b[:text] }).to eq(%w[2026 2027])
      end

      it "bm -> returns to month selection" do
        parts = %w[cal bm 2026 0 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("2026")
      end

      it "bd -> returns to day selection" do
        parts = %w[cal bd 2026 3 0 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("March 2026")
      end

      it "bh -> returns to hour selection" do
        parts = %w[cal bh 2026 3 20 0 0]
        result = described_class.process(parts, locale: :en)

        expect(result[:text]).to include("20 March 2026")
      end
    end

    describe "no-op (_)" do
      it "returns nil" do
        parts = %w[cal _ 0 0 0 0 0]
        result = described_class.process(parts, locale: :en)
        expect(result).to be_nil
      end
    end
  end

  describe "edge cases" do
    it "handles today when no future time slots remain within lead time" do
      travel_back
      travel_to Time.zone.local(2026, 3, 15, 22, 10)

      # Cutoff is 00:10 on March 16 (22:10 + 2h).
      # Day 15 hours: cutoff day is March 16, so March 15 is fully in the past.
      # The day grid should dim day 15 entirely.
      parts = %w[cal sm 2026 3 0 0 0]
      result = described_class.process(parts, locale: :en)

      rows = result[:keyboard].inline_keyboard
      day_rows = rows[2..-2]
      all_buttons = day_rows.flatten

      day_15_btn = all_buttons.find { |b| b[:callback_data]&.include?("sd:2026:3:15") }
      expect(day_15_btn).to be_nil # day 15 should be dimmed (shown as "·")
    end

    it "handles December to January navigation" do
      parts = %w[cal nm 2027 1 0 0 0]
      result = described_class.process(parts, locale: :en)

      expect(result[:text]).to include("January 2027")
    end

    it "handles leap year February" do
      travel_back
      travel_to Time.zone.local(2028, 1, 15, 10, 0)

      parts = %w[cal sm 2028 2 0 0 0]
      result = described_class.process(parts, locale: :en)

      rows = result[:keyboard].inline_keyboard
      day_buttons = rows[2..-2].flatten
      selectable_days = day_buttons.select { |b| b[:text].match?(/^\d+$/) }.map { |b| b[:text].to_i }

      expect(selectable_days).to include(29) # leap year
    end

    it "creates datetime in the user's timezone on selection" do
      moscow_tz = ActiveSupport::TimeZone["Moscow"]
      parts = %w[cal si 2026 3 20 19 30]
      result = described_class.process(parts, locale: :en, time_zone: moscow_tz)

      # 19:30 Moscow time = 16:30 UTC
      expect(result[:datetime]).to eq(moscow_tz.local(2026, 3, 20, 19, 30))
      expect(result[:datetime].utc.hour).to eq(16)
    end

    it "disables prev month button when at current month" do
      parts = %w[cal sm 2026 3 0 0 0]
      result = described_class.process(parts, locale: :en)

      nav_row = result[:keyboard].inline_keyboard[0]
      prev_btn = nav_row[0]

      # February 2026 is in the past, so prev button should be disabled
      expect(prev_btn[:callback_data]).to eq("cal:_:0:0:0:0:0")
    end
  end
end
