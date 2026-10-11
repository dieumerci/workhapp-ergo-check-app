# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1. You can set it to `auto` to automatically start a worker
# for each available processor.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Create or migrate the database before the web server (and the job worker below) starts.
#
# Not every platform runs a pre-deploy step, and a custom start command replaces the image's
# entrypoint, so Puma can be started against a brand-new, empty database. The job worker plugin
# below queries its own tables on boot and, finding none, crashes and takes Puma down with it
# ("relation solid_queue_recurring_tasks does not exist ... Solid Queue has gone away").
#
# `db:prepare` is idempotent and Rails serialises concurrent migrations with an advisory lock,
# so running it again after a pre-deploy step costs about a second. `db:seed` creates nothing in
# production unless ALLOW_DEMO_SEED=true. Set SKIP_DB_PREPARE=1 where schema changes must only
# ever happen in a separate release step.
# (Plain Ruby only: this file is read before Rails, so ActiveSupport's `present?` does not exist yet.)
if ENV["RAILS_ENV"] == "production" && !ENV["DATABASE_URL"].to_s.empty? && ENV["SKIP_DB_PREPARE"].to_s.empty?
  system(File.expand_path("../bin/rails", __dir__), "db:prepare", "db:seed") ||
    abort("db:prepare db:seed failed, so the web server was not started")
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
