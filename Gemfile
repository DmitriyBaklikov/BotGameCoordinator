source "https://rubygems.org"

ruby "~> 3.2"

gem "rails", "~> 7.2"
gem "sqlite3", "~> 1.7"
gem "puma", "~> 6.0"
gem "telegram-bot", "~> 0.16"
gem "good_job", "~> 3.0"
gem "redis-client", "~> 0.22"
gem "bootsnap", require: false

group :development do
  gem "error_highlight", ">= 0.4.0", platforms: [:ruby]
end

group :development, :test do
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.0"
  gem "shoulda-matchers", "~> 5.0"
  gem "faker", "~> 3.0"
  gem "rubocop", "~> 1.60", require: false
  gem "rubocop-rails", "~> 2.23", require: false
  gem "rubocop-rspec", "~> 2.26", require: false
  gem "timecop", "~> 0.9"
  gem "debug", platforms: %i[mri windows]
end
