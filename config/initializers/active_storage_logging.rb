# Active Storage logs "Generated URL for file at key: ... (<signed url>)" at DEBUG.
# That URL is the one-minute download link for an export, effectively a password
# for the file, and the app documents RAILS_LOG_LEVEL=debug as a supported
# setting. Its log subscriber is detached so the link never reaches any log.
# (The request-log line for the download itself is silenced in config/application.rb.)
Rails.application.config.after_initialize do
  ActiveStorage::LogSubscriber.detach_from(:active_storage)
end
