class PaymentsController < ApplicationController
  protect_from_forgery except: :stripe_upgrade

  def stripe_upgrade
    unless current_user && !current_user.admin? && !current_user.pro?
      redirect_to movies_path, alert: 'You are not eligible for upgrade.'
      return
    end
    token = params[:stripeToken]
    begin
      charge = Stripe::Charge.create({
        amount: 999, # $9.99 in cents
        currency: 'usd',
        source: token,
        description: "Upgrade to Pro for user ##{current_user.id}"
      })
      # Mark user as pro
      current_user.update(pro: true)
      payment = Payment.create(user_id: current_user.id, amount: 9.99, currency: 'usd', status: 'completed')
      # Send confirmation email
      PaymentMailer.with(user: current_user, payment: payment).pro_upgrade.deliver_later
      redirect_to success_payments_path, notice: 'Payment successful! You are now a Pro user.'
    rescue Stripe::CardError => e
      redirect_to upgrade_payment_path, alert: e.message
    end
  end
  def upgrade
    unless current_user && !current_user.admin? && !current_user.pro?
      redirect_to movies_path, alert: 'You are not eligible for upgrade.'
      return
    end
    @payment = Payment.new
  end
  before_action :require_admin, only: [:index]
  def index
    @payments = Payment.all
  end

  private

  def require_admin
    unless current_user && current_user.admin?
      redirect_to movies_path, alert: 'You are not authorized to view payments.'
    end
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

  def success
  end

  private

  def payment_params
    params.require(:payment).permit(:amount, :currency, :status, :user_id)
  end

  def set_payment
    @payment = Payment.find(params[:id])
  end
end
