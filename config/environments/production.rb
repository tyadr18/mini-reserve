Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # HTTPS の背後で動かすときは FORCE_SSL=true を設定する
  config.assume_ssl = ENV["FORCE_SSL"] == "true"
  config.force_ssl = ENV["FORCE_SSL"] == "true"

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
end
