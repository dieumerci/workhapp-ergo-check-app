require "test_helper"
require "pg"
require "socket"
require "net/http"

# The first start on a brand-new platform database: Postgres exists, the tables do not.
#
# A hosting service may skip the pre-deploy step (or replace the image's entrypoint with its own start
# command), so the web process cannot assume someone already ran `db:prepare`. With the job worker inside
# Puma this used to crash on the first boot ("relation solid_queue_recurring_tasks does not exist" followed by
# "Solid Queue has gone away, stopping Puma"). This starts the real server, the way a platform does, against an
# empty database, and checks that it comes up healthy with its tables created.
class FirstBootTest < ActiveSupport::TestCase
  DEADLINE = 120 # seconds

  test "puma starts against an empty database, prepares it, and answers the health check" do
    name = "workhappy_first_boot_#{Process.pid}_#{SecureRandom.hex(3)}"
    port = free_port
    log = Rails.root.join("tmp", "#{name}.log")
    admin_connection { |db| db.exec(%(CREATE DATABASE "#{name}")) }
    pid = nil

    begin
      pid = Process.spawn(
        { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => "a" * 64, "DATABASE_URL" => database_url(name), "PORT" => port.to_s,
          "SOLID_QUEUE_IN_PUMA" => "1", "SECRET_KEY_BASE_DUMMY" => nil, "ALLOW_DEMO_SEED" => nil, "SKIP_DB_PREPARE" => nil, "DYNO" => nil },
        "bundle", "exec", "puma", "-C", "config/puma.rb",
        chdir: Rails.root.to_s, out: log.to_s, err: %i[child out], pgroup: true
      )

      status = wait_for_health(pid, port)

      assert_equal "200", status, "the server did not come up healthy against an empty database:\n#{File.read(log).lines.last(25).join}"
      with_database(name) do |db|
        %w[assessments admins solid_queue_recurring_tasks solid_cache_entries].each do |table|
          assert db.exec_params("SELECT to_regclass($1)", [ "public.#{table}" ]).first["to_regclass"], "#{table} was not created"
        end
        assert_equal "0", db.exec("SELECT COUNT(*) FROM admins").first["count"], "demo accounts must not appear without ALLOW_DEMO_SEED"
      end

      # The job worker inside Puma only crashed a few seconds after the first healthy answer, so
      # a single health check proves nothing. Give it time, then check the server is still there.
      sleep 8
      assert_nil Process.waitpid(pid, Process::WNOHANG), "the server stopped by itself after starting:\n#{File.read(log).lines.last(25).join}"
      assert_equal "200", wait_for_health(pid, port)
    ensure
      stop(pid)
      admin_connection { |db| db.exec(%(DROP DATABASE IF EXISTS "#{name}" WITH (FORCE))) }
      FileUtils.rm_f(log)
    end
  end

  private

  def wait_for_health(pid, port)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      return "process exited" if Process.waitpid(pid, Process::WNOHANG)

      begin
        response = Net::HTTP.start("127.0.0.1", port, open_timeout: 1, read_timeout: 2) { |http| http.get("/up") }
        return response.code
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout
        sleep 0.5
      end
    end
    "timed out"
  end

  def stop(pid)
    return unless pid

    Process.kill("TERM", -pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    begin
      Process.kill("KILL", -pid) if pid
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1].tap { server.close }
  end

  def connection_settings
    ActiveRecord::Base.connection_db_config.configuration_hash
  end

  # The same server and credentials as the test database, but a database of its own.
  def database_url(name)
    config = connection_settings
    credentials = config[:username] ? "#{config[:username]}#{":#{config[:password]}" if config[:password]}@" : ""
    "postgres://#{credentials}#{config[:host]}#{":#{config[:port]}" if config[:port]}/#{name}"
  end

  def pg_options(dbname)
    config = connection_settings
    { host: config[:host], port: config[:port], user: config[:username], password: config[:password], dbname: dbname }.compact
  end

  def admin_connection
    db = PG.connect(pg_options("postgres"))
    yield db
  ensure
    db&.close
  end

  def with_database(name)
    db = PG.connect(pg_options(name))
    yield db
  ensure
    db&.close
  end
end
