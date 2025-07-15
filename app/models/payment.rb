class Payment < ApplicationRecord
  belongs_to :user

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }
  validates :payment_method, presence: true, inclusion: { in: %w[credit_card paypal bank_transfer] }
  validates :transaction_id, presence: true, uniqueness: true
  validates :user_id, presence: true
  validate :valid_payment_method
  validate :valid_status
  validate :valid_amount
  validate :valid_transaction_id

end
