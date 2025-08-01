source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use propshaft for asset management 
gem 'propshaft'

gem "actioncable"
# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage for file uploads [https://guides.rubyonrails.org/active_storage_overview.html]
gem "image_processing", "~> 1.2"
gem "mini_magick", "~> 4.9"

gem 'whenever', require: false

# Use Redis for caching and background jobs [https://redis.io/]
gem "redis", "~> 4.0"

# Use Sidekiq for background processing [https://sidekiq.org]
gem "sidekiq", "~> 6.0"

# Use Stripe for payment processing [https://stripe.com/docs/api]
gem "stripe", "~> 5.0"

# Use Devise for user authentication 
gem "devise", "~> 4.8"

# Use FactoryBot for test data generation 
gem "factory_bot_rails", "~> 6.0"

# Use Faker for generating fake data in tests 
gem "faker", "~> 2.0"

# Use RuboCop for code linting and formatting [https://rubocop.org]
gem "rubocop", "~> 1.0"

# Use Pry for debugging 
gem "pry-rails", "~> 0.3.9"

# Use Nokogiri for HTML/XML parsing [https://nokogiri.org]
gem "nokogiri", "~> 1.12"

# Use Faraday for HTTP requests [https://lostisland.github.io/faraday/]
gem "faraday", "~> 1.0"

# Use Kaminari for pagination 
gem "kaminari", "~> 1.2"

# Use Pundit for authorization 
gem "pundit", "~> 2.0"

# Use ActiveModelSerializers for JSON serialization 
gem "active_model_serializers", "~> 0.10"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS) 
gem "rack-cors", "~> 1.1"

# Use Mailgun for email delivery [https://www.mailgun.com]
gem "mailgun-ruby", "~> 1.2"

# Use Sentry for error tracking and performance monitoring [https://sentry.io]
gem "sentry-rails", "~> 4.0"

# Use Rollbar for error tracking [https://rollbar.com]
gem "rollbar", "~> 3.0"

gem "fiddle"
# Use Elasticsearch for search functionality [https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html]
gem "elasticsearch-model"
gem "elasticsearch-rails"
# Use dotenv for environment variable management 
gem 'dotenv-rails'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "sqlite3"

end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem 'pundit-matchers'
end

gem "pg", group: :production

