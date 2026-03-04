class GameCreator
  include FsmState

  STEPS = %w[
    sport_type
    event_type
    datetime
    location
    location_name
    max_participants
    min_participants
    visibility
    confirmation
    relaunch_datetime
  ].freeze

  DATETIME_FORMATS = ["%d.%m.%Y %H:%M", "%d/%m/%Y %H:%M"].freeze

  def self.start(user, controller)
    locale = user.locale.to_sym
    controller.write_fsm_state(user.id, step: "sport_type", data: {})
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.select_sport_type", locale: locale),
      reply_markup: TelegramMessageBuilder.sport_type_keyboard(locale: locale)
    )
  end

  def self.start_relaunch(user, controller, archived_game)
    locale = user.locale.to_sym
    controller.write_fsm_state(
      user.id,
      step: "relaunch_datetime",
      data: {
        relaunch_game_id: archived_game.id,
        sport_type:       archived_game.sport_type,
        event_type:       archived_game.event_type,
        location_id:      archived_game.location_id,
        max_participants: archived_game.max_participants,
        min_participants: archived_game.min_participants,
        visibility:       archived_game.visibility
      }
    )
    cal = TelegramCalendar.start(locale: locale, time_zone: user.tz)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.enter_relaunch_datetime", title: archived_game.title, locale: locale) + "\n\n" + cal[:text],
      reply_markup: cal[:keyboard]
    )
  end

  def self.handle_callback(user, controller, step, value)
    state  = controller.read_fsm_state(user.id)
    return unless state

    locale = user.locale.to_sym

    case step
    when "sport_type"
      advance_to_event_type(user, controller, state, value, locale)
    when "event_type"
      advance_to_datetime(user, controller, state, value, locale)
    when "location_id"
      handle_location_selection(user, controller, state, value, locale)
    when "visibility"
      advance_to_confirmation(user, controller, state, value, locale)
    when "confirm"
      handle_confirmation(user, controller, state, value, locale)
    end
  end

  def self.handle_text(user, controller, text)
    state  = controller.read_fsm_state(user.id)
    return unless state

    locale = user.locale.to_sym

    case state[:step]
    when "datetime"
      handle_datetime_input(user, controller, state, text, locale)
    when "location_name"
      handle_location_name_input(user, controller, state, text, locale)
    when "max_participants"
      handle_max_participants_input(user, controller, state, text, locale)
    when "min_participants"
      handle_min_participants_input(user, controller, state, text, locale)
    when "relaunch_datetime"
      handle_relaunch_datetime(user, controller, state, text, locale)
    end
  end

  def self.prompt_self_vote(user, controller, game)
    locale = user.locale.to_sym
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.self_vote_prompt", title: game.title, locale: locale),
      reply_markup: TelegramMessageBuilder.vote_keyboard(game, locale: locale)
    )
  end

  def self.finish(user, controller, data)
    locale = user.locale.to_sym
    ActiveRecord::Base.transaction do
      location = if data[:location_id].present?
                   Location.find(data[:location_id])
                 else
                   Location.find_or_create_by!(
                     organizer: user,
                     name:      data[:location_name]
                   )
                 end

      game = Game.create!(
        organizer:       user,
        location:        location,
        sport_type:      data[:sport_type],
        event_type:      data[:event_type],
        scheduled_at:    data[:scheduled_at],
        max_participants: data[:max_participants].to_i,
        min_participants: data[:min_participants].to_i,
        visibility:      data[:visibility] || "public_game",
        status:          :active
      )

      controller.clear_fsm_state(user.id)
      NotifySubscribersJob.perform_later(game.id) if game.public_game?

      card     = TelegramMessageBuilder.event_card(game, locale: locale, time_zone: user.tz)
      keyboard = TelegramMessageBuilder.vote_keyboard(game, locale: locale)
      controller.send_message(
        user.telegram_id,
        "#{I18n.t("bot.game_created", locale: locale)}\n\n#{card[:text]}",
        reply_markup: keyboard
      )

      game
    end
  rescue ActiveRecord::RecordInvalid => e
    controller.send_message(user.telegram_id, I18n.t("bot.game_create_error", error: e.message, locale: locale))
    nil
  end

  class << self
    private

    def advance_to_event_type(user, controller, state, value, locale)
      data = state[:data].merge(sport_type: value)
      controller.write_fsm_state(user.id, step: "event_type", data: data)
      controller.send_message(
        user.telegram_id,
        I18n.t("bot.select_event_type", locale: locale),
        reply_markup: TelegramMessageBuilder.event_type_keyboard(locale: locale)
      )
    end

    def advance_to_datetime(user, controller, state, value, locale)
      data = state[:data].merge(event_type: value)
      controller.write_fsm_state(user.id, step: "datetime", data: data)
      cal = TelegramCalendar.start(locale: locale, time_zone: user.tz)
      controller.send_message(user.telegram_id, cal[:text], reply_markup: cal[:keyboard])
    end

    def handle_location_selection(user, controller, state, value, locale)
      if value == "new"
        controller.write_fsm_state(user.id, step: "location_name", data: state[:data])
        controller.send_message(user.telegram_id, I18n.t("bot.enter_location_name", locale: locale))
      else
        data = state[:data].merge(location_id: value.to_i)
        controller.write_fsm_state(user.id, step: "max_participants", data: data)
        controller.send_message(user.telegram_id, I18n.t("bot.enter_max_participants", locale: locale))
      end
    end

    def advance_to_confirmation(user, controller, state, value, locale)
      data = state[:data].merge(visibility: value)
      controller.write_fsm_state(user.id, step: "confirmation", data: data)
      summary = build_summary(data, locale, user.tz)
      controller.send_message(
        user.telegram_id,
        "#{I18n.t("bot.confirm_game", locale: locale)}\n\n#{summary}",
        reply_markup: TelegramMessageBuilder.confirmation_keyboard(locale: locale)
      )
    end

    def handle_confirmation(user, controller, state, value, locale)
      if value == "yes"
        finish(user, controller, state[:data])
      else
        controller.clear_fsm_state(user.id)
        controller.send_message(user.telegram_id, I18n.t("bot.game_cancelled", locale: locale))
      end
    end

    def handle_datetime_input(user, controller, state, text, locale)
      scheduled_at = parse_datetime(text, user.tz)
      unless scheduled_at
        controller.send_message(user.telegram_id, I18n.t("bot.invalid_datetime_format", locale: locale))
        return
      end

      unless scheduled_at > Game::MIN_HOURS_BEFORE_GAME.hours.from_now
        controller.send_message(user.telegram_id, I18n.t("bot.datetime_too_soon", hours: Game::MIN_HOURS_BEFORE_GAME, locale: locale))
        return
      end

      data = state[:data].merge(scheduled_at: scheduled_at.iso8601)
      controller.write_fsm_state(user.id, step: "location", data: data)

      existing_locations = Location.where(organizer_id: user.id)
      controller.send_message(
        user.telegram_id,
        I18n.t("bot.select_location", locale: locale),
        reply_markup: TelegramMessageBuilder.location_keyboard(existing_locations, locale: locale)
      )
    end

    def handle_location_name_input(user, controller, state, text, locale)
      data = state[:data].merge(location_name: text.strip)
      controller.write_fsm_state(user.id, step: "max_participants", data: data)
      controller.send_message(user.telegram_id, I18n.t("bot.enter_max_participants", locale: locale))
    end

    def handle_max_participants_input(user, controller, state, text, locale)
      max = text.to_i
      unless max.between?(2, 100)
        controller.send_message(user.telegram_id, I18n.t("bot.invalid_max_participants", locale: locale))
        return
      end

      data = state[:data].merge(max_participants: max)
      controller.write_fsm_state(user.id, step: "min_participants", data: data)
      controller.send_message(user.telegram_id, I18n.t("bot.enter_min_participants", max: max, locale: locale))
    end

    def handle_min_participants_input(user, controller, state, text, locale)
      min = text.to_i
      max = state[:data][:max_participants].to_i

      unless min.between?(1, max)
        controller.send_message(user.telegram_id,
                                I18n.t("bot.invalid_min_participants", max: max, locale: locale))
        return
      end

      data = state[:data].merge(min_participants: min)
      controller.write_fsm_state(user.id, step: "visibility", data: data)
      controller.send_message(
        user.telegram_id,
        I18n.t("bot.select_visibility", locale: locale),
        reply_markup: TelegramMessageBuilder.visibility_keyboard(locale: locale)
      )
    end

    def handle_relaunch_datetime(user, controller, state, text, locale)
      scheduled_at = parse_datetime(text, user.tz)
      unless scheduled_at
        controller.send_message(user.telegram_id, I18n.t("bot.invalid_datetime_format", locale: locale))
        return
      end

      unless scheduled_at > Game::MIN_HOURS_BEFORE_GAME.hours.from_now
        controller.send_message(user.telegram_id, I18n.t("bot.datetime_too_soon", hours: Game::MIN_HOURS_BEFORE_GAME, locale: locale))
        return
      end

      data = state[:data].merge(scheduled_at: scheduled_at.iso8601)
      controller.clear_fsm_state(user.id)
      finish(user, controller, data)
    end

    def parse_datetime(text, time_zone)
      Time.use_zone(time_zone) do
        DATETIME_FORMATS.each do |fmt|
          return Time.zone.strptime(text.strip, fmt)
        rescue ArgumentError
          next
        end
      end
      nil
    end

    def build_summary(data, locale, time_zone)
      sport = I18n.t("game.sport_types.#{data[:sport_type]}", locale: locale)
      evt   = I18n.t("game.event_types.#{data[:event_type]}", locale: locale)
      dt    = begin
                Time.parse(data[:scheduled_at].to_s).in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M")
              rescue StandardError
                data[:scheduled_at]
              end
      loc   = data[:location_name] || "ID:#{data[:location_id]}"
      vis   = I18n.t("game.visibility.#{data[:visibility]&.sub("_game", "")}", locale: locale)

      <<~TEXT
        🏟 #{sport} (#{evt})
        📅 #{dt}
        📍 #{loc}
        👥 #{data[:max_participants]} max / #{data[:min_participants]} min
        👁 #{vis}
      TEXT
    end
  end
end
