# Inline calendar widget for Telegram bots.
# Provides a multi-step date/time picker: Year -> Month -> Day -> Hour -> Minute.
# All dates/times are displayed in the user's timezone; the final datetime is
# returned as an absolute Time (UTC-backed) for storage.
#
# Callback data format: cal:<action>:<year>:<month>:<day>:<hour>:<minute>
# Actions:
#   sy  - select year        sm  - select month       sd  - select day
#   sh  - select hour        si  - select minute (interval)
#   pm  - prev month (nav)   nm  - next month (nav)
#   by  - back to year       bm  - back to month      bd  - back to day
#   bh  - back to hour       _   - no-op (disabled/empty button)
class TelegramCalendar
  MONTH_NAMES = {
    en: %w[January February March April May June July August September October November December],
    ru: %w[Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь]
  }.freeze

  MONTH_ABBR = {
    en: %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec],
    ru: %w[Янв Фев Мар Апр Май Июн Июл Авг Сен Окт Ноя Дек]
  }.freeze

  DAY_HEADERS = {
    en: %w[Mo Tu We Th Fr Sa Su],
    ru: %w[Пн Вт Ср Чт Пт Сб Вс]
  }.freeze

  MINUTE_INTERVALS = [0, 15, 30, 45].freeze

  # Returns the initial calendar keyboard (year selection) and prompt text.
  def self.start(locale: :en, time_zone: Time.zone)
    {
      text: I18n.t("bot.calendar.select_date", locale: locale),
      keyboard: build_year(time_zone)
    }
  end

  # Process a calendar callback. Returns one of:
  # - { text:, keyboard: }  => edit message with new keyboard
  # - { datetime: Time }    => selection complete
  # - nil                   => no-op (disabled button pressed)
  def self.process(parts, locale: :en, time_zone: Time.zone)
    action = parts[1]
    y, m, d, h, mn = parts[2..6].map(&:to_i)

    case action
    when "sy"
      { text: I18n.t("bot.calendar.month", year: y, locale: locale),
        keyboard: build_month(y, locale, time_zone) }
    when "sm"
      { text: I18n.t("bot.calendar.day", month: month_name(m, locale), year: y, locale: locale),
        keyboard: build_day(y, m, locale, time_zone) }
    when "sd"
      { text: I18n.t("bot.calendar.hour", date: format_date(y, m, d, locale), locale: locale),
        keyboard: build_hour(y, m, d, locale, time_zone) }
    when "sh"
      { text: I18n.t("bot.calendar.minute", date: format_date(y, m, d, locale),
                                             hour: format("%02d", h), locale: locale),
        keyboard: build_minute(y, m, d, h, locale, time_zone) }
    when "si"
      # Create time in the user's timezone — Rails converts to UTC for storage.
      { datetime: time_zone.local(y, m, d, h, mn) }
    when "pm", "nm"
      { text: I18n.t("bot.calendar.day", month: month_name(m, locale), year: y, locale: locale),
        keyboard: build_day(y, m, locale, time_zone) }
    when "by"
      { text: I18n.t("bot.calendar.select_date", locale: locale),
        keyboard: build_year(time_zone) }
    when "bm"
      { text: I18n.t("bot.calendar.month", year: y, locale: locale),
        keyboard: build_month(y, locale, time_zone) }
    when "bd"
      { text: I18n.t("bot.calendar.day", month: month_name(m, locale), year: y, locale: locale),
        keyboard: build_day(y, m, locale, time_zone) }
    when "bh"
      { text: I18n.t("bot.calendar.hour", date: format_date(y, m, d, locale), locale: locale),
        keyboard: build_hour(y, m, d, locale, time_zone) }
    when "_"
      nil
    end
  end

  class << self
    private

    # The earliest selectable time — now + minimum lead time, expressed in the user's timezone.
    def cutoff(time_zone)
      (Time.current + Game::MIN_HOURS_BEFORE_GAME.hours).in_time_zone(time_zone)
    end

    def build_year(time_zone)
      co = cutoff(time_zone)
      years = (co.year..(co.year + 1)).to_a

      rows = [years.map { |y| btn(y.to_s, "sy:#{y}:0:0:0:0") }]
      markup(rows)
    end

    def build_month(year, locale, time_zone)
      co = cutoff(time_zone)
      abbr = MONTH_ABBR[locale] || MONTH_ABBR[:en]

      rows = (1..12).each_slice(4).map do |months|
        months.map do |m|
          if year == co.year && m < co.month
            btn("·", "_:0:0:0:0:0")
          else
            btn(abbr[m - 1], "sm:#{year}:#{m}:0:0:0")
          end
        end
      end

      rows << [btn("« #{I18n.t("bot.calendar.back", locale: locale)}", "by:#{year}:0:0:0:0")]
      markup(rows)
    end

    def build_day(year, month, locale, time_zone)
      co = cutoff(time_zone)
      now_local = Time.current.in_time_zone(time_zone)
      first = Date.new(year, month, 1)
      last = first.end_of_month
      headers = DAY_HEADERS[locale] || DAY_HEADERS[:en]
      mname = month_name(month, locale)

      rows = []

      # Navigation row: « Month Year »
      prev_m = first.prev_month
      next_m = first.next_month
      current_first = Date.new(co.year, co.month, 1)

      can_prev = Date.new(prev_m.year, prev_m.month, 1) >= current_first
      can_next = next_m.year <= now_local.year + 1

      prev_btn = can_prev ? btn("«", "pm:#{prev_m.year}:#{prev_m.month}:0:0:0") : btn(" ", "_:0:0:0:0:0")
      next_btn = can_next ? btn("»", "nm:#{next_m.year}:#{next_m.month}:0:0:0") : btn(" ", "_:0:0:0:0:0")
      rows << [prev_btn, btn("#{mname} #{year}", "_:0:0:0:0:0"), next_btn]

      # Weekday headers
      rows << headers.map { |d| btn(d, "_:0:0:0:0:0") }

      # Day cells
      offset = first.cwday - 1 # Monday=0 offset
      cells = Array.new(offset) { btn(" ", "_:0:0:0:0:0") }

      (1..last.day).each do |d|
        date = Date.new(year, month, d)
        if date < co.to_date
          cells << btn("·", "_:0:0:0:0:0")
        elsif date == co.to_date && !any_future_time_slots?(co)
          cells << btn("·", "_:0:0:0:0:0")
        else
          cells << btn(d.to_s, "sd:#{year}:#{month}:#{d}:0:0")
        end
      end

      # Pad to complete last week
      cells << btn(" ", "_:0:0:0:0:0") while cells.length % 7 != 0
      cells.each_slice(7) { |week| rows << week }

      # Back button
      rows << [btn("« #{I18n.t("bot.calendar.back", locale: locale)}", "bm:#{year}:0:0:0:0")]
      markup(rows)
    end

    def build_hour(year, month, day, locale, time_zone)
      co = cutoff(time_zone)
      is_cutoff_day = Date.new(year, month, day) == co.to_date

      rows = (0..23).each_slice(6).map do |hours|
        hours.map do |h|
          if is_cutoff_day && h < co.hour
            btn("·", "_:0:0:0:0:0")
          elsif is_cutoff_day && h == co.hour && MINUTE_INTERVALS.none? { |mn| mn > co.min }
            btn("·", "_:0:0:0:0:0")
          else
            btn(format("%02d", h), "sh:#{year}:#{month}:#{day}:#{h}:0")
          end
        end
      end

      rows << [btn("« #{I18n.t("bot.calendar.back", locale: locale)}", "bd:#{year}:#{month}:0:0:0")]
      markup(rows)
    end

    def build_minute(year, month, day, hour, locale, time_zone)
      co = cutoff(time_zone)
      is_cutoff_hour = Date.new(year, month, day) == co.to_date && hour == co.hour

      row = MINUTE_INTERVALS.map do |mn|
        if is_cutoff_hour && mn <= co.min
          btn("·", "_:0:0:0:0:0")
        else
          btn("#{format("%02d", hour)}:#{format("%02d", mn)}",
              "si:#{year}:#{month}:#{day}:#{hour}:#{mn}")
        end
      end

      rows = [row]
      rows << [btn("« #{I18n.t("bot.calendar.back", locale: locale)}", "bh:#{year}:#{month}:#{day}:0:0")]
      markup(rows)
    end

    def any_future_time_slots?(co)
      # Check if there are any valid hour+minute combos left on the cutoff day
      (co.hour..23).any? do |h|
        if h == co.hour
          MINUTE_INTERVALS.any? { |mn| mn > co.min }
        else
          true
        end
      end
    end

    def btn(text, callback_suffix)
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: text,
        callback_data: "cal:#{callback_suffix}"
      )
    end

    def markup(rows)
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: rows)
    end

    def month_name(month, locale)
      names = MONTH_NAMES[locale] || MONTH_NAMES[:en]
      names[month - 1]
    end

    def format_date(year, month, day, locale)
      "#{day} #{month_name(month, locale)} #{year}"
    end
  end
end
