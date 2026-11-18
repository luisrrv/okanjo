require_relative "boot"

require "rails"
# Pick the frameworks you want (ADR 0002): no Active Storage, Action Text or Action Mailbox.
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Okanjo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Japanese-only UI (ADR 0018). Times are stored in UTC and shown in Japan time.
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [ :ja ]
    config.time_zone = "Tokyo"

    # The LINE Login channel that owns the LIFF app (ADR 0024). Checked when a LINE sign-in
    # needs it, not at boot, so building the image doesn't need it.
    config.x.line.channel_id = ENV["LINE_CHANNEL_ID"]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
