class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include TelegramHandler
  include FsmState

  def start!(*)
    Commands::StartHandler.call(self, current_user)
  end

  def newgame!(*)
    Commands::NewGameHandler.call(self, current_user)
  end

  def mygames!(*)
    Commands::MyGamesHandler.call(self, current_user)
  end

  def archive!(*)
    Commands::ArchiveHandler.call(self, current_user)
  end

  def publicgames!(*)
    Commands::PublicGamesHandler.call(self, current_user)
  end

  def settings!(*)
    Commands::SettingsHandler.call(self, current_user)
  end

  def callback_query(data)
    CallbackRouter.dispatch(self, current_user, data)
  end

  def message(message)
    return unless message.text

    FsmHandler.handle(self, current_user, message.text)
  end

  private

  def current_user
    @current_user ||= User.find_or_create_from_telegram(from)
  end
end
