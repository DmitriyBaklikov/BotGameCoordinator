secrets_path = Rails.root.join("config", "secrets.yml")
token = if File.exist?(secrets_path)
  config = YAML.load(ERB.new(File.read(secrets_path)).result)
  config[Rails.env]&.dig("telegram_bot_token")&.presence
end
token ||= ENV["TELEGRAM_BOT_TOKEN"]

Rails.application.config.telegram_bot_token = token

if token.present?
  Telegram.bots_config = { default: { token: token } }
end

bot_username = if File.exist?(secrets_path)
  config = YAML.load(ERB.new(File.read(secrets_path)).result)
  config[Rails.env]&.dig("telegram_bot_username")&.presence
end
bot_username ||= ENV["TELEGRAM_BOT_USERNAME"]

Rails.application.config.telegram_bot_username = bot_username

