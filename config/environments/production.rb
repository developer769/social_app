require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Terminated at the proxy in front of the app, so Rails is told the original
  # request was HTTPS -- without this every generated URL comes out as http.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Redirects http to https and sets HSTS. A session cookie travelling in the
  # clear once is enough to lose an account.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]

  # Only the hostnames this app is actually served on. Rails refuses anything
  # else, which stops a Host header being used to poison a generated link --
  # including the password reset and email confirmation links, which are
  # credentials.
  config.hosts = ENV.fetch("APP_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  config.hosts << /.*\.internal\z/ if config.hosts.any?
  # The load balancer's health check arrives without a matching Host header.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # Redis, which is already required for Sidekiq. The default file store does
  # not survive a redeploy and is not shared between containers.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://redis:6379/1"),
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.warn(message: "cache unavailable", method: method, error: exception.class.name)
    }
  }

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Mail. Password reset and email confirmation links are credentials, so both
  # halves of sending one come from the environment: the host the link points
  # at, and the server that delivers it. A link built with the wrong host is a
  # reset nobody can complete, and one that is never delivered is worse than
  # not offering the feature at all.
  #
  # APP_HOST falls back instead of raising because this file is also loaded by
  # `assets:precompile` during the image build, where no host is set and none
  # is needed. deploy/install.sh refuses to deploy while APP_HOST is empty.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "localhost"), protocol: "https"
  }

  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    # Every mailer is called with deliver_later, so a delivery failure raises
    # inside the Sidekiq worker, where it is retried and logged -- not in the
    # request, where it would turn a failed send into a failed page.
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address:              ENV.fetch("SMTP_ADDRESS"),
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:            ENV["SMTP_USERNAME"].presence,
      password:             ENV["SMTP_PASSWORD"].presence,
      authentication:       :plain,
      enable_starttls_auto: true
    }
  else
    # No SMTP server configured. The Rails default would attempt localhost:25
    # and raise on every send; going nowhere quietly is no worse and keeps the
    # worker's retry queue from filling with mail that can never leave.
    config.action_mailer.delivery_method = :test
    config.action_mailer.perform_deliveries = false
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
