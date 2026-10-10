# Fails fast when exports would be written to a disk that disappears.
#
# Heroku-like platforms give each dyno an ephemeral disk and set DYNO. With the
# "local" Disk service the worker would write the CSV to its own disk, the web
# dyno could not see it, and every download would 404 after a restart. Refusing to
# boot is better than losing exports quietly.
module ActiveStorageGuard
  class MisconfiguredStorage < StandardError; end

  module_function

  def verify!(service_name:, ephemeral_platform:)
    return unless ephemeral_platform && service_name.to_s == "local"

    raise MisconfiguredStorage,
      "ACTIVE_STORAGE_SERVICE is not set. This platform's disk is ephemeral, so exports stored on it would vanish " \
      "and downloads would fail. Set ACTIVE_STORAGE_SERVICE=amazon with the AWS_* variables (see .env.example)."
  end
end
