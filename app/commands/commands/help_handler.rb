module Commands
  class HelpHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      text = <<~TEXT
        Available commands:

        /start - main menu
        /newgame - create a new game
        /mygames - manage your games
        /publicgames - browse public games
        /settings - bot settings
        /help - show this help
      TEXT

      controller.send_message(
        controller.from.id,
        text
      )
    end
  end
end

