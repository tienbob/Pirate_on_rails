ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Set a test secret key base to avoid MessageVerifier errors
Rails.application.config.secret_key_base = 'test_secret_key_base_that_is_long_enough_to_meet_requirements_minimum_30_characters_for_security'

begin
  require 'factory_bot_rails'
rescue LoadError
  # factory_bot_rails not available in this environment
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include ActionMailer::TestHelper
    include FactoryBot::Syntax::Methods if defined?(FactoryBot)
  end
end
