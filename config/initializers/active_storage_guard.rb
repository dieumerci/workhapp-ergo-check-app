if Rails.env.production?
  ActiveStorageGuard.verify!(
    service_name: Rails.configuration.active_storage.service,
    ephemeral_platform: ENV["DYNO"].present?
  )
end
