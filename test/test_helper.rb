ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
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
    # fixtures :all

  # Add more helper methods to be used by all tests here...
  # Only include FactoryBot syntax methods when FactoryBot is available to avoid
  # raising a NameError in environments where the factory gem isn't loaded.
  include FactoryBot::Syntax::Methods if defined?(FactoryBot)
  end
end
