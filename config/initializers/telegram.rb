secrets_path = Rails.root.join("config", "secrets.yml")
secrets = if File.exist?(secrets_path)
  YAML.load(ERB.new(File.read(secrets_path)).result)
end

token = secrets&.dig(Rails.env, "telegram_bot_token")&.presence || ENV["TELEGRAM_BOT_TOKEN"]
bot_username = secrets&.dig(Rails.env, "telegram_bot_username")&.presence || ENV["TELEGRAM_BOT_USERNAME"]

Rails.application.config.telegram_bot_token = token
Rails.application.config.telegram_bot_username = bot_username

if token.present?
  Telegram.bots_config = { default: { token: token } }
end
