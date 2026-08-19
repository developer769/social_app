source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# ---- Prachar additions ----------------------------------------------------
# Authentication: Active Model has_secure_password
gem "bcrypt", "~> 3.1.7"

# Background jobs (spec 31). Redis-backed; Solid Queue was skipped on purpose.
gem "sidekiq", "~> 8.1"
gem "redis", "~> 5.4"

# Authorization + tenancy scoping (spec 4)
gem "action_policy", "~> 0.7"

# Server-rendered components; the spec mandates app/components (spec 6, 20)
gem "view_component", "~> 4.0"

# Request throttling for login, invitations and webhooks (spec 32)
gem "rack-attack", "~> 6.7"

# Pagination for gallery, calendar and analytics tables
gem "pagy", "~> 9.3"

# Structured single-line request logs carrying workspace context (spec 7)
gem "lograge", "~> 0.14"

group :development, :test do
  # Specs (spec 34)
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Drives headless Chromium for bin/screenshot, so a rendered page can be
  # looked at during development rather than inferred from ERB.
  gem "selenium-webdriver"

  # N+1 detection for the dashboard and calendar queries
  gem "bullet", "~> 8.0"

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Blocks ALL outbound HTTP so a live social/AI API call in a spec fails loudly (spec 34)
  gem "webmock", "~> 3.24"
  gem "shoulda-matchers", "~> 6.4"
  gem "rspec-sidekiq", "~> 5.1"
  gem "capybara"
end
