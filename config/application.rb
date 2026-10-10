require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Workhappy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # The only Active Storage use is the generated CSV exports; there are no
    # image variants, so no image library (libvips) is needed or loaded.
    config.active_storage.variant_processor = :disabled

    # Active Storage's own routes include unauthenticated direct-upload endpoints
    # that this app never uses (anyone could create blobs, and with S3 obtain a
    # presigned PUT URL for the bucket). They are not drawn; config/routes.rb adds
    # back only the signed, short-lived download link the Disk service needs.
    config.active_storage.draw_routes = false

    # The signed download path is effectively a one-minute password for an export,
    # so requests to it are not written to the request log.
    config.middleware.insert_before Rails::Rack::Logger, Rails::Rack::SilenceRequest, path: %r{\A/rails/active_storage/disk/}

    # The release-plan and safeguards pages are internal ops notes (they name
    # production resources and DDL). Visible in development and test, hidden from
    # tenants in production unless SHOW_OPS_PAGES=true (e.g. on a demo deployment).
    config.x.ops_pages = ActiveModel::Type::Boolean.new.cast(ENV.fetch("SHOW_OPS_PAGES") { Rails.env.production? ? "false" : "true" })

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
