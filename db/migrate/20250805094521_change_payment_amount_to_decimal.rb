class ChangePaymentAmountToDecimal < ActiveRecord::Migration[8.0]
  def change
    # Change amount column from integer to decimal with precision for currency
    change_column :payments, :amount, :decimal, precision: 10, scale: 2
  end
end
