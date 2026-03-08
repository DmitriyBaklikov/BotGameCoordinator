module Commands
  class HelpHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      text = [
        I18n.t("bot.help.title", locale: locale),
        "",
        I18n.t("bot.help.start", locale: locale),
        I18n.t("bot.help.newgame", locale: locale),
        I18n.t("bot.help.mygames", locale: locale),
        I18n.t("bot.help.publicgames", locale: locale),
        I18n.t("bot.help.settings", locale: locale),
        I18n.t("bot.help.help", locale: locale)
      ].join("\n")

      controller.send_message(controller.from.id, text)
    end
  end
end
