class PaymentsController < ApplicationController
  protect_from_forgery

  # Stripe Checkout Session for subscription
  def create_checkout_session
    prices = Stripe::Price.list(
      lookup_keys: [params[:lookup_key]],
      expand: ['data.product']
    )
    begin
      session = Stripe::Checkout::Session.create({
        mode: 'subscription',
        line_items: [{
          quantity: 1,
          price: prices.data[0].id
        }],
        success_url: payments_success_url + '?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: payments_upgrade_url,
      })
      redirect_to session.url, allow_other_host: true
    rescue StandardError => e
      render json: { error: { message: e.message } }, status: :bad_request
    end
  end

  # Stripe Billing Portal Session
  def create_portal_session
    checkout_session_id = params[:session_id]
    checkout_session = Stripe::Checkout::Session.retrieve(checkout_session_id)
    return_url = payments_success_url
    session = Stripe::BillingPortal::Session.create({
      customer: checkout_session.customer,
      return_url: return_url
    })
    redirect_to session.url, allow_other_host: true
  end

  # Stripe Webhook endpoint
  skip_before_action :verify_authenticity_token, only: [:webhook]
  def webhook
    webhook_secret = ENV['STRIPE_API_KEY']
    payload = request.body.read
    event = nil
    if webhook_secret.present?
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      begin
        event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError
        head :bad_request and return
      rescue Stripe::SignatureVerificationError
        Rails.logger.warn '⚠️  Webhook signature verification failed.'
        head :bad_request and return
      end
    else
      data = JSON.parse(payload, symbolize_names: true)
      event = Stripe::Event.construct_from(data)
    end
    event_type = event['type']
    data_object = event['data']['object']
    case event_type
    when 'customer.subscription.deleted'
      Rails.logger.info "Subscription canceled: #{event.id}"
    when 'customer.subscription.updated'
      Rails.logger.info "Subscription updated: #{event.id}"
    when 'customer.subscription.created'
      Rails.logger.info "Subscription created: #{event.id}"
    when 'customer.subscription.trial_will_end'
      Rails.logger.info "Subscription trial will end: #{event.id}"
    when 'entitlements.active_entitlement_summary.updated'
      Rails.logger.info "Active entitlement summary updated: #{event.id}"
    end
    render json: { status: 'success' }
  end
  def upgrade
    unless current_user && !current_user.admin? && !current_user.pro?
      redirect_to movies_path, alert: 'You are not eligible for upgrade.'
      return
    end
    @payment = Payment.new
  end
  before_action :require_admin, only: [:index, :new, :create]
  def index
    @payments = Payment.all
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def new
    @payment = Payment.new
    respond_to do |format|
      format.html
      format.json { render json: @payment }
    end
  end

  def create
    @payment = Payment.new(payment_params)
    if @payment.save
      PaymentMailerJob.perform_later(@payment.user_id, @payment.id)
      redirect_to @payment, notice: 'Payment was successfully created.'
    else
      render :new
    end
  end

  def success
  end

  def cancel
    redirect_to movies_path, alert: 'Payment was canceled.'
  end
  def edit
    @payment = Payment.find(params[:id])
  end 
  def update
    @payment = Payment.find(params[:id])
    if @payment.update(payment_params)
      redirect_to @payment, notice: 'Payment was successfully updated.'
    else
      render :edit
    end
  end
  def destroy
    @payment = Payment.find(params[:id])
    if @payment.destroy
      redirect_to payments_path, notice: 'Payment was successfully deleted.'
    else
      redirect_to payments_path, alert: 'Failed to delete payment.'
    end
  end
  private

  def require_admin
    unless current_user && current_user.admin?
      redirect_to movies_path, alert: 'You are not authorized to view payments.'
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :currency, :status, :user_id)
  end

  def set_payment
    @payment = Payment.find(params[:id])
  end
end
