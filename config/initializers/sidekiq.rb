require "sidekiq"

Sidekiq.configure_server do |config|
  # Loaded only in the worker. Running the schedule from the web process too
  # would enqueue every recurring job twice.
  config.on(:startup) do
    schedule_file = Rails.root.join("config/schedule.yml")
    next unless File.exist?(schedule_file)

    # Replaces the whole schedule rather than merging, so a job removed from the
    # file actually stops running instead of living on in Redis for ever.
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule_file))
  end
end
