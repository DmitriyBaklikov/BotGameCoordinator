require_relative "boot"

require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module SportBot
  class Application < Rails::Application
    config.load_defaults 7.2

    config.api_only = false

    config.i18n.available_locales = %i[en ru]
    config.i18n.default_locale = :en
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.yml")]

    config.active_job.queue_adapter = :good_job

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
