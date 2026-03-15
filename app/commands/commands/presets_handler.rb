module Commands
  class PresetsHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      presets = user.game_presets.includes(:location)

      if presets.empty?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.presets.no_presets", locale: locale)
        )
        return
      end

      controller.send_message(
        user.telegram_id,
        I18n.t("bot.presets.preset_list_title", locale: locale),
        reply_markup: TelegramMessageBuilder.preset_list_keyboard(presets, locale: locale)
      )
    end

    def self.show_preset(controller, user, preset_id)
      locale = user.locale.to_sym
      preset = user.game_presets.includes(:location, :game_preset_invitees).find_by(id: preset_id)
      return unless preset

      summary = PresetService.preset_summary(preset, locale: locale)
      controller.send_message(
        user.telegram_id,
        "#{I18n.t("bot.presets.summary_title", locale: locale)}\n\n#{summary}",
        reply_markup: TelegramMessageBuilder.preset_actions_keyboard(preset.id, locale: locale)
      )
    end
  end
end
