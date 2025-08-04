class Payment < ApplicationRecord
  belongs_to :user

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { 
    in: %w[completed failed refunded cancelled],
    message: "%{value} is not a valid status" 
  }
  validates :user_id, presence: true
  validates :currency, presence: true, inclusion: { 
    in: %w[usd eur gbp sgd],
    message: "%{value} is not a supported currency" 
  }
  validates :stripe_charge_id, uniqueness: true, allow_blank: true

  # Scopes for better querying
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # State checking methods
  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def failed?
    status == 'failed'
  end

  def processing?
    status == 'processing'
  end

  # Format amount for display
  def formatted_amount
    "$#{'%.2f' % amount}"
  end

  # Safely transition payment status
  def mark_as_completed!
    ActiveRecord::Base.transaction do
      update!(status: 'completed')
      
      # Upgrade user if payment is completed
      user.update!(role: 'pro') if user.free?
      
      Rails.logger.info "Payment #{id} marked as completed for user #{user.email}"
    end
  end

  def mark_as_failed!(error_msg = nil)
    ActiveRecord::Base.transaction do
      update!(
        status: 'failed',
        error_message: error_msg
      )
      
      Rails.logger.warn "Payment #{id} marked as failed for user #{user.email}: #{error_msg}"
    end
  end

  # Callback to log payment changes
  after_update :log_status_change

  private

  def log_status_change
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      Rails.logger.info "Payment #{id} status changed from #{old_status} to #{new_status}"
    end
  end
end
