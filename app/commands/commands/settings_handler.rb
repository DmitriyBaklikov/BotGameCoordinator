module Commands
  class SettingsHandler
    PAGE_SIZE = 10

    def self.call(controller, user)
      locale = user.locale.to_sym

      controller.send_message(
        controller.from.id,
        I18n.t("bot.settings_menu", locale: locale),
        reply_markup: settings_keyboard(user, locale)
      )
    end

    def self.show_timezone_picker(controller, user)
      locale = user.locale.to_sym
      controller.send_message(
        user.telegram_id,
        I18n.t("bot.settings.select_timezone", locale: locale),
        reply_markup: timezone_keyboard(user)
      )
    end

    # --- My Subscriptions (paginated) ---

    def self.show_my_subscriptions(controller, user, page: 0)
      locale = user.locale.to_sym
      query  = subscribed_organizers_query(user)
      total  = query.count
      organizers = query.limit(PAGE_SIZE).offset(page * PAGE_SIZE)

      if total.zero?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.settings.subscriptions_empty", locale: locale),
          reply_markup: back_only_keyboard(locale)
        )
        return
      end

      total_pages = (total.to_f / PAGE_SIZE).ceil
      header = I18n.t("bot.settings.page_info", current: page + 1, total: total_pages, locale: locale)
      buttons = organizer_buttons(organizers, prefix: "settings:unsubscribe")
      buttons.concat(navigation_row(page, total_pages, "settings:my_subs", locale))

      controller.send_message(
        user.telegram_id,
        "#{I18n.t("bot.settings.my_subscriptions", locale: locale)}\n#{header}",
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      )
    end

    # --- Organizers (paginated) ---

    def self.show_organizers(controller, user, page: 0)
      locale = user.locale.to_sym
      query  = available_organizers_query(user)
      total  = query.count
      organizers = query.limit(PAGE_SIZE).offset(page * PAGE_SIZE)

      if total.zero?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.settings.organizers_empty", locale: locale),
          reply_markup: back_only_keyboard(locale)
        )
        return
      end

      total_pages = (total.to_f / PAGE_SIZE).ceil
      header = I18n.t("bot.settings.page_info", current: page + 1, total: total_pages, locale: locale)
      buttons = organizer_buttons(organizers, prefix: "settings:subscribe")
      buttons.concat(navigation_row(page, total_pages, "settings:organizers", locale))

      controller.send_message(
        user.telegram_id,
        "👥 #{I18n.t("bot.settings.organizers", locale: locale)}\n#{header}",
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      )
    end

    # --- Search results (paginated) ---

    def self.show_search_results(controller, user, search_query, list_type, page: 0)
      locale = user.locale.to_sym
      base   = list_type == :my_subs ? subscribed_organizers_query(user) : available_organizers_query(user)
      query  = apply_search(base, search_query)
      total  = query.count
      organizers = query.limit(PAGE_SIZE).offset(page * PAGE_SIZE)

      if total.zero?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.settings.no_search_results", locale: locale),
          reply_markup: back_only_keyboard(locale)
        )
        return
      end

      prefix = list_type == :my_subs ? "settings:unsubscribe" : "settings:subscribe"
      callback_prefix = list_type == :my_subs ? "settings:my_subs_s" : "settings:orgs_s"

      total_pages = (total.to_f / PAGE_SIZE).ceil
      header = I18n.t("bot.settings.page_info", current: page + 1, total: total_pages, locale: locale)
      buttons = organizer_buttons(organizers, prefix: prefix)
      buttons.concat(search_navigation_row(page, total_pages, callback_prefix, search_query, locale))

      title = list_type == :my_subs ? I18n.t("bot.settings.my_subscriptions", locale: locale) : I18n.t("bot.settings.organizers", locale: locale)

      controller.send_message(
        user.telegram_id,
        "🔍 #{title}\n#{header}",
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      )
    end

    # --- Keyboards ---

    def self.settings_keyboard(user, locale)
      rows = [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.settings.my_subscriptions", locale: locale),
            callback_data: "settings:my_subs:0"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.settings.organizers", locale: locale),
            callback_data: "settings:organizers:0"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.settings.locale_en", locale: locale),
            callback_data: "settings:locale:en"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.settings.locale_ru", locale: locale),
            callback_data: "settings:locale:ru"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🕐 #{I18n.t("bot.settings.timezone", locale: locale)} (#{user.time_zone})",
            callback_data: "settings:timezone"
          )
        ]
      ]

      if user.organizer?
        rows << [Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.manage_presets", locale: locale),
          callback_data: "settings:presets"
        )]
      end

      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: rows)
    end

    def self.timezone_keyboard(user)
      buttons = User::SUPPORTED_TIME_ZONES.keys.each_slice(4).map do |group|
        group.map do |tz_key|
          label = user.time_zone == tz_key ? "✅ #{tz_key}" : tz_key
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          label,
            callback_data: "settings:set_tz:#{tz_key}"
          )
        end
      end

      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    end

    # --- Private helpers ---

    def self.subscribed_organizers_query(user)
      User.joins("INNER JOIN subscriptions ON subscriptions.organizer_id = users.id")
          .where(subscriptions: { subscriber_id: user.id })
          .order(:first_name, :last_name)
    end

    def self.available_organizers_query(user)
      User.where(role: :organizer)
          .where.not(id: user.id)
          .where.not(id: user.subscriptions.select(:organizer_id))
          .order(:first_name, :last_name)
    end

    def self.apply_search(query, search_query)
      sanitized = "%#{search_query}%"
      query.where(
        "users.first_name ILIKE :q OR users.last_name ILIKE :q OR users.username ILIKE :q OR CAST(users.telegram_id AS TEXT) = :exact",
        q: sanitized, exact: search_query
      )
    end

    def self.organizer_buttons(organizers, prefix:)
      is_subscribe = prefix.end_with?("subscribe") && !prefix.end_with?("unsubscribe")
      organizers.map do |org|
        icon = is_subscribe ? "➕" : "✅"
        [Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "#{icon} #{org.display_name}",
          callback_data: "#{prefix}:#{org.id}"
        )]
      end
    end

    def self.navigation_row(page, total_pages, callback_prefix, locale)
      search_callback = callback_prefix == "settings:my_subs" ? "settings:search_subs" : "settings:search_orgs"
      nav = []

      nav << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.prev_page", locale: locale),
        callback_data: "#{callback_prefix}:#{page - 1}"
      ) if page > 0

      nav << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.search", locale: locale),
        callback_data: search_callback
      )

      nav << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.next_page", locale: locale),
        callback_data: "#{callback_prefix}:#{page + 1}"
      ) if page + 1 < total_pages

      rows = []
      rows << nav if nav.any?
      rows << [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.back", locale: locale),
        callback_data: "settings:back"
      )]
      rows
    end

    def self.search_navigation_row(page, total_pages, callback_prefix, search_query, locale)
      nav = []

      nav << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.prev_page", locale: locale),
        callback_data: "#{callback_prefix}:#{page - 1}:#{search_query}"
      ) if page > 0

      nav << Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.next_page", locale: locale),
        callback_data: "#{callback_prefix}:#{page + 1}:#{search_query}"
      ) if page + 1 < total_pages

      rows = []
      rows << nav if nav.any?
      rows << [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: I18n.t("bot.settings.back", locale: locale),
        callback_data: "settings:back"
      )]
      rows
    end

    def self.back_only_keyboard(locale)
      Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: [
          [Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t("bot.settings.back", locale: locale),
            callback_data: "settings:back"
          )]
        ]
      )
    end

    private_class_method :subscribed_organizers_query, :available_organizers_query,
                         :apply_search, :organizer_buttons, :navigation_row,
                         :search_navigation_row, :back_only_keyboard
  end
end
