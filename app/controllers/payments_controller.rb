class PaymentsController < ApplicationController
  protect_from_forgery except: [:webhook]
  before_action :authenticate_user!, except: [:webhook]
  before_action :require_admin, only: [:index]
  before_action :set_payment, only: [:show]
  before_action :check_rate_limit, except: [:webhook]

  # Admin: List all payments
  def index
    @payments = Payment.includes(:user)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  # Stripe Checkout Session for subscription
  def create_checkout_session
    unless params[:price].present?
      render json: { error: { message: "Missing or empty price parameter (Stripe Price ID)." } }, 
             status: :bad_request
      return
    end

    # Validate price parameter format
    unless params[:price].match?(/^price_[a-zA-Z0-9]+$/)
      render json: { error: { message: "Invalid price ID format." } }, 
             status: :bad_request
      return
    end

    ActiveRecord::Base.transaction do
      # Create pending payment record
      payment = Payment.create!(
        user: current_user,
        amount: 0, # Will be updated after successful checkout
        status: 'pending',
        currency: 'usd'
      )

      begin
        session = Stripe::Checkout::Session.create({
          mode: 'subscription',
          customer_email: current_user.email,
          client_reference_id: current_user.id.to_s,
          metadata: {
            user_id: current_user.id,
            payment_id: payment.id
          },
          line_items: [{
            quantity: 1,
            price: params[:price]
          }],
          success_url: success_payments_url + '?session_id={CHECKOUT_SESSION_ID}',
          cancel_url: upgrade_payment_url,
          allow_promotion_codes: true,
          billing_address_collection: 'required',
          payment_method_types: ['card']
        })

        # Update payment with session ID
        payment.update!(stripe_charge_id: session.id)
        
        redirect_to session.url, allow_other_host: true
        
      rescue Stripe::StripeError => e
        payment.update!(status: 'failed', error_message: e.message)
        render json: { error: { message: "Payment processing failed: #{e.message}" } }, 
               status: :payment_required
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: { message: "Database error: #{e.message}" } }, 
           status: :internal_server_error
  end

  # Stripe Billing Portal Session
  def create_portal_session
    unless params[:session_id].present?
      flash[:alert] = 'Invalid session ID'
      redirect_to upgrade_payment_path
      return
    end

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])
      
      # Verify session belongs to current user
      unless checkout_session.client_reference_id == current_user.id.to_s
        flash[:alert] = 'Unauthorized access'
        redirect_to upgrade_payment_path
        return
      end

      return_url = success_payments_url
      portal_session = Stripe::BillingPortal::Session.create({
        customer: checkout_session.customer,
        return_url: return_url
      })
      
      redirect_to portal_session.url, allow_other_host: true
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      flash[:alert] = 'Unable to access billing portal. Please try again.'
      redirect_to upgrade_payment_path
    end
  end

  # Stripe Webhook endpoint with proper security
  def webhook
    # Verify webhook signature
    webhook_secret = Rails.application.credentials.stripe[:webhook_secret]
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
    rescue JSON::ParserError => e
      Rails.logger.error "Webhook JSON parsing failed: #{e.message}"
      head :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Webhook signature verification failed: #{e.message}"
      head :bad_request
      return
    end

    # Process the event in a transaction
    ActiveRecord::Base.transaction do
      case event.type
      when 'checkout.session.completed'
        handle_checkout_completed(event.data.object)
      when 'customer.subscription.created'
        handle_subscription_created(event.data.object)
      when 'customer.subscription.updated'
        handle_subscription_updated(event.data.object)
      when 'customer.subscription.deleted'
        handle_subscription_deleted(event.data.object)
      when 'invoice.payment_succeeded'
        handle_payment_succeeded(event.data.object)
      when 'invoice.payment_failed'
        handle_payment_failed(event.data.object)
      else
        Rails.logger.info "Unhandled webhook event: #{event.type}"
      end
    end

    render json: { status: 'success' }
  rescue StandardError => e
    Rails.logger.error "Webhook processing error: #{e.message}\n#{e.backtrace.join("\n")}"
    head :internal_server_error
  end
  def upgrade
    unless current_user&.free?
      redirect_to series_index_path, alert: 'You are not eligible for upgrade.'
      return
    end
    @payment = Payment.new
  end

  def success
    unless params[:session_id].present?
      flash[:alert] = 'Invalid session'
      redirect_to series_index_path
      return
    end

    begin
      session = Stripe::Checkout::Session.retrieve(params[:session_id])
      
      # Verify session belongs to current user
      unless session.client_reference_id == current_user.id.to_s
        flash[:alert] = 'Unauthorized access'
        redirect_to series_index_path
        return
      end

      # Check if already processed
      existing_payment = Payment.find_by(stripe_charge_id: session.id)
      if existing_payment&.completed?
        flash[:notice] = "Your account is already upgraded!"
        redirect_to series_index_path
        return
      end

      ActiveRecord::Base.transaction do
        if session.payment_status == 'paid'
          # Update user role
          current_user.update!(role: 'pro')
          
          # Create or update payment record
          payment = Payment.find_or_initialize_by(stripe_charge_id: session.id)
          payment.assign_attributes(
            user: current_user,
            amount: (session.amount_total || 0) / 100.0,
            status: 'completed',
            currency: session.currency || 'usd'
          )
          payment.save!
          
          # Send confirmation email
          UserMailerJob.perform_later(current_user.id, 'pro_upgrade', payment.id)
          
          flash[:notice] = "Welcome to Pro! Your account has been upgraded successfully."
        else
          flash[:alert] = "Payment verification failed. Please contact support."
        end
      end
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe success page error: #{e.message}"
      flash[:alert] = "Payment verification failed. Please contact support."
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Database error during upgrade: #{e.message}"
      flash[:alert] = "Upgrade failed. Please contact support."
    end
    
    redirect_to series_index_path
  end

  def cancel
    redirect_to series_index_path, alert: 'Payment was canceled.'
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to series_index_path, alert: 'You are not authorized to view payments.'
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :currency, :status, :user_id)
  end

  def set_payment
    @payment = Payment.find(params[:id])
  end
  
  def check_rate_limit
    rate_limit_key = "payment_#{request.remote_ip}_#{current_user&.id}"
    
    if Rails.cache.read(rate_limit_key).to_i >= 10 # 10 payment attempts per hour
      flash[:alert] = 'Too many payment attempts. Please try again later.'
      redirect_to series_index_path
    else
      Rails.cache.increment(rate_limit_key, 1, expires_in: 1.hour)
    end
  end

  # Webhook event handlers
  def handle_checkout_completed(session)
    user = User.find_by(id: session.client_reference_id)
    return unless user

    payment = Payment.find_by(stripe_charge_id: session.id)
    return unless payment

    payment.update!(
      amount: (session.amount_total || 0) / 100.0,
      status: 'completed',
      currency: session.currency || 'usd'
    )
    
    Rails.logger.info "Checkout completed for user #{user.email}"
  end

  def handle_subscription_created(subscription)
    customer = Stripe::Customer.retrieve(subscription.customer)
    user = User.find_by(email: customer.email)
    return unless user

    user.update!(role: 'pro') unless user.pro?
    
    Payment.create!(
      user: user,
      amount: (subscription.plan&.amount || 0) / 100.0,
      status: map_stripe_status(subscription.status),
      currency: subscription.plan&.currency || 'usd',
      stripe_charge_id: subscription.latest_invoice || subscription.id
    )
    
    Rails.logger.info "Subscription created for user #{user.email}"
  end

  def handle_subscription_updated(subscription)
    customer = Stripe::Customer.retrieve(subscription.customer)
    user = User.find_by(email: customer.email)
    return unless user

    status = subscription.status
    if %w[unpaid past_due canceled incomplete expired].include?(status)
      user.update!(role: 'free') if user.pro?
      Rails.logger.info "User #{user.email} downgraded due to subscription status: #{status}"
    elsif status == 'active' && user.free?
      user.update!(role: 'pro')
      Rails.logger.info "User #{user.email} upgraded due to subscription status: #{status}"
    end
  end

  def handle_subscription_deleted(subscription)
    customer = Stripe::Customer.retrieve(subscription.customer)
    user = User.find_by(email: customer.email)
    return unless user

    user.update!(role: 'free') if user.pro?
    Rails.logger.info "User #{user.email} downgraded due to subscription cancellation"
  end

  def handle_payment_succeeded(invoice)
    customer = Stripe::Customer.retrieve(invoice.customer)
    user = User.find_by(email: customer.email)
    return unless user

    # Record successful payment
    Payment.create!(
      user: user,
      amount: (invoice.amount_paid || 0) / 100.0,
      status: 'completed',
      currency: invoice.currency || 'usd',
      stripe_charge_id: invoice.id
    )
    
    Rails.logger.info "Payment succeeded for user #{user.email}"
  end

  def handle_payment_failed(invoice)
    customer = Stripe::Customer.retrieve(invoice.customer)
    user = User.find_by(email: customer.email)
    return unless user

    # Record failed payment
    Payment.create!(
      user: user,
      amount: (invoice.amount_due || 0) / 100.0,
      status: 'failed',
      currency: invoice.currency || 'usd',
      stripe_charge_id: invoice.id,
      error_message: 'Payment failed'
    )
    
    Rails.logger.info "Payment failed for user #{user.email}"
  end

  def map_stripe_status(stripe_status)
    case stripe_status
    when 'active', 'trialing' then 'completed'
    when 'incomplete', 'incomplete_expired' then 'pending'
    when 'past_due', 'canceled', 'unpaid' then 'failed'
    else 'pending'
    end
  end
end
