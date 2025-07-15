class PaymentsController < ApplicationController
  def index
    @payments = Payment.all
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def new
    @payment = Payment.new
  end

  def create
    @payment = Payment.new(payment_params)
    if @payment.save
      redirect_to @payment, notice: 'Payment was successfully created.'
    else
      render :new
    end
  end

  private

  def payment_params
    params.require(:payment).permit(:amount, :currency, :status, :user_id)
  end

  def set_payment
    @payment = Payment.find(params[:id])
  end
end
