require "ostruct"

class TelegramBotController < Telegram::Bot::UpdatesController
  include TelegramHandler
  include FsmState

  def start!(*)
    ::Commands::StartHandler.call(self, current_user)
  end

  def help!(*)
    ::Commands::HelpHandler.call(self, current_user)
  end

  def newgame!(*)
    ::Commands::NewGameHandler.call(self, current_user)
  end

  def mygames!(*)
    ::Commands::MyGamesHandler.call(self, current_user)
  end

  def archive!(*)
    ::Commands::ArchiveHandler.call(self, current_user)
  end

  def publicgames!(*)
    ::Commands::PublicGamesHandler.call(self, current_user)
  end

  def settings!(*)
    ::Commands::SettingsHandler.call(self, current_user)
  end

  def callback_query(data)
    ::CallbackRouter.dispatch(self, current_user, data)
  end

  def message(message)
    message = OpenStruct.new(message) if message.is_a?(Hash)
    return unless message.text

    ::FsmHandler.handle(self, current_user, message.text)
  end

  def from
    @from ||= begin
      raw = super
      if raw.respond_to?(:id)
        raw
      else
        OpenStruct.new(
          id:            raw["id"],
          username:      raw["username"],
          first_name:    raw["first_name"],
          last_name:     raw["last_name"],
          language_code: raw["language_code"]
        )
      end
    end
  end

  def chat
    @chat ||= begin
      raw = super
      if raw.respond_to?(:id)
        raw
      else
        OpenStruct.new(
          id:    raw["id"],
          type:  raw["type"],
          title: raw["title"]
        )
      end
    end
  end

  private

  def current_user
    @current_user ||= ::User.find_or_create_from_telegram(from)
  end
end

