require 'logger'

class FilteredLogger < Logger
  def warn(message = nil, &block)
    return if message&.include?('deprecated') # Filter out deprecation warnings
    super
  end
end

Sidekiq.configure_server do |config|
  config.logger = FilteredLogger.new(STDOUT)
end