class PaymentEvent < ApplicationRecord
  belongs_to :payment

  validates :event_type, presence: true
  validates :event_data, presence: true

  EVENT_TYPES = %w[
    created updated completed failed refunded
    webhook_received stripe_sync user_upgraded
    manual_adjustment dispute_created
  ].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :webhooks, -> { where(source: 'webhook') }
  scope :manual, -> { where(source: 'manual') }

  # Serialize event data as JSON
  serialize :event_data, JSON

  def self.log_event(payment, event_type, data = {}, source = 'system')
    create!(
      payment: payment,
      event_type: event_type,
      event_data: data.merge(timestamp: Time.current.iso8601),
      source: source
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log payment event: #{e.message}"
  end

  def formatted_data
    return {} unless event_data.is_a?(Hash)
    
    event_data.except('timestamp').transform_keys(&:humanize)
  end
end
