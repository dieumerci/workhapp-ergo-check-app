# Runs after initialization: ActiveStorageGuard lives in lib/ and is autoloaded, and
# autoloaded constants are not available while initializers are still running.
# (Referencing it directly here raised NameError and stopped every production boot,
# which dev and test never exercise; test/production_boot_test.rb now does.)
if Rails.env.production?
  Rails.application.config.after_initialize do
    ActiveStorageGuard.verify!(
      service_name: Rails.configuration.active_storage.service,
      ephemeral_platform: ENV["DYNO"].present?
    )
  end
end
