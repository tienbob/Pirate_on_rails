class PaymentsController < ApplicationController
  protect_from_forgery

  # Stripe Checkout Session for subscription
  def create_checkout_session
    if params[:price].blank?
      render json: { error: { message: "Missing or empty price parameter (Stripe Price ID)." } }, status: :bad_request and return
    end
    begin
      session = Stripe::Checkout::Session.create({
        mode: 'subscription',
        line_items: [{
          quantity: 1,
          price: params[:price]
        }],
        success_url: success_payments_url + '?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: upgrade_payment_url,
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
    return_url = success_payments_url
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
      # Upgrade user to pro when subscription is created
      begin
        customer_id = data_object["customer"]
        customer = Stripe::Customer.retrieve(customer_id)
        user = User.find_by(email: customer.email)
        if user && user.role != "pro"
          user.update(role: "pro")
          Rails.logger.info "User \\#{user.email} upgraded to pro."
        end
      rescue => e
        Rails.logger.error "Failed to upgrade user to pro: \\#{e.message}"
      end
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


  def success
    if params[:session_id].present?
      begin
        session = Stripe::Checkout::Session.retrieve(params[:session_id])
        customer = Stripe::Customer.retrieve(session.customer)
        user = User.find_by(email: customer.email)
        if user && user.role != "pro"
          user.update(role: "pro")
          flash[:notice] = "Your account has been upgraded to Pro!"
        end
      rescue => e
        Rails.logger.error "Stripe upgrade error: \\#{e.message}"
      end
    end
  end

  def cancel
    redirect_to movies_path, alert: 'Payment was canceled.'
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
