class PaymentsController < ApplicationController
  protect_from_forgery except: [:webhook]
  before_action :authenticate_user!, except: [:webhook, :success]
  before_action :require_admin, only: [:index, :new, :create]
  before_action :set_payment, only: [:show]
  before_action :check_rate_limit, except: [:webhook, :success, :manage_subscription, :cancel_subscription]

  # Admin: List all payments
  def index
    @payments = Payment.includes(:user)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  # Show payment details (admin or payment owner)
  def show
    unless current_user.admin? || @payment.user == current_user
      redirect_to series_index_path, alert: 'You are not authorized to view this payment.'
      return
    end
  end

  # Admin: New payment form
  def new
    @payment = Payment.new
  end

  # Admin: Create payment manually
  def create
    @payment = Payment.new(payment_params)
    
    if @payment.save
      redirect_to @payment, notice: 'Payment was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
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

    begin
      # Generate a secure token for this session
      token = SecureRandom.urlsafe_base64(32)
      
      # Create Stripe session without creating database record yet
      session = Stripe::Checkout::Session.create({
        mode: 'subscription',
        customer_email: current_user.email,
        client_reference_id: current_user.id.to_s,
        metadata: {
          user_id: current_user.id,
          user_email: current_user.email,
          success_token: token
        },
        line_items: [{
          quantity: 1,
          price: params[:price]
        }],
        success_url: success_payments_url + "?token=#{token}",
        cancel_url: cancel_payment_url,
        allow_promotion_codes: true,
        billing_address_collection: 'required',
        payment_method_types: ['card']
      })
      
      # Store session info in Rails cache temporarily for reference
      Rails.cache.write("checkout_session_#{session.id}", {
        user_id: current_user.id,
        price_id: params[:price],
        success_token: token,
        created_at: Time.current
      }, expires_in: 1.hour)
      
      # Also store token mapping to session ID for security
      Rails.cache.write("success_token_#{token}", session.id, expires_in: 1.hour)
      
      redirect_to session.url, allow_other_host: true
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe checkout session creation failed: #{e.message}"
      render json: { error: { message: "Payment processing failed: #{e.message}" } }, 
             status: :payment_required
    rescue StandardError => e
      Rails.logger.error "Checkout session error: #{e.message}"
      render json: { error: { message: "An unexpected error occurred. Please try again." } }, 
             status: :internal_server_error
    end
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
    unless params[:token].present?
      flash[:alert] = 'Invalid or missing security token'
    redirect_to series_index_path
      return
    end

    begin
      # Get session ID from secure token
      session_id = Rails.cache.read("success_token_#{params[:token]}")
      unless session_id
        flash[:alert] = 'Invalid or expired security token'
        redirect_to root_path
        return
      end

      # Clean up the token (one-time use)
      Rails.cache.delete("success_token_#{params[:token]}")

      session = Stripe::Checkout::Session.retrieve(session_id)
      
      # Verify the token matches what we stored in metadata
      unless session.metadata['success_token'] == params[:token]
        flash[:alert] = 'Security token mismatch'
        redirect_to root_path
        return
      end
      
      # Find the user from the session data (since they might not be logged in)
      user = User.find_by(id: session.client_reference_id)
      unless user
        flash[:alert] = 'User not found'
        redirect_to root_path
        return
      end

      # Check if already processed to prevent duplicate records
      existing_payment = Payment.find_by(stripe_charge_id: session_id)
      if existing_payment&.completed?
        # Sign in user if not already signed in
        unless user_signed_in? && current_user.id == user.id
          sign_in(user)
          Rails.logger.info "User #{user.email} automatically signed in after payment success (existing payment)"
        end
        flash[:notice] = "Your account is already upgraded!"
        redirect_to series_index_path
        return
      end

      ActiveRecord::Base.transaction do
        if session.payment_status == 'paid'
          # Create payment record only after successful payment
          payment = Payment.create!(
            user: user,
            amount: (session.amount_total || 0) / 100.0,
            status: 'completed',
            currency: session.currency || 'usd',
            stripe_charge_id: session_id
          )
          
          # Update user role
          user.update!(role: 'pro')
          
          # Clean up cache
          Rails.cache.delete("checkout_session_#{session_id}")
          
          # Send confirmation email (if UserMailerJob exists)
          begin
            UserMailerJob.perform_later(user.id, 'pro_upgrade', payment.id)
          rescue NameError
            Rails.logger.info "UserMailerJob not defined, skipping email"
          end
          
          flash[:notice] = "Welcome to Pro! Your account has been upgraded successfully."
        else
          flash[:alert] = "Payment verification failed. Please contact support."
        end
      end

      # Sign in user AFTER successful transaction
      unless user_signed_in? && current_user.id == user.id
        sign_in(user)
        Rails.logger.info "User #{user.email} automatically signed in after payment success"
      end
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe success page error: #{e.message}"
      flash[:alert] = "Payment verification failed. Please contact support."
      redirect_to root_path
      return
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Database error during upgrade: #{e.message}"
      flash[:alert] = "Upgrade failed. Please contact support."
      redirect_to root_path  
      return
    end
    
    redirect_to series_index_path
  end

  def cancel
    redirect_to series_index_path, alert: 'Payment was canceled.'
  end

  # Subscription management page for Pro users
  def manage_subscription
    unless current_user&.pro?
      redirect_to series_index_path, alert: 'You do not have an active subscription.'
      return
    end

    begin
      # Find user's active subscription
      @subscription_info = get_user_subscription_info(current_user)
      
      if @subscription_info.nil?
        flash[:alert] = 'No active subscription found.'
        redirect_to series_index_path
        return
      end
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error in manage_subscription: #{e.message}"
      flash[:alert] = 'Unable to load subscription information. Please try again.'
      redirect_to series_index_path
    end
  end

  # Cancel user's subscription
  def cancel_subscription
    unless current_user&.pro?
      redirect_to series_index_path, alert: 'You do not have an active subscription.'
      return
    end

    begin
      # Find and cancel user's subscription
      subscription_info = get_user_subscription_info(current_user)
      
      if subscription_info.nil?
        flash[:alert] = 'No active subscription found.'
        redirect_to series_index_path
        return
      end

      # Cancel the subscription at the end of the current billing period
      cancelled_subscription = Stripe::Subscription.update(
        subscription_info[:subscription_id],
        {
          cancel_at_period_end: true,
          metadata: {
            cancelled_by_user: 'true',
            cancelled_at: Time.current.to_s
          }
        }
      )

      # Log the cancellation
      Rails.logger.info "Subscription cancelled by user #{current_user.email}: #{subscription_info[:subscription_id]}"
      
      # Create a cancellation record (optional - for audit trail)
      Payment.create!(
        user: current_user,
        amount: 0.01, # Small amount to satisfy validation
        status: 'cancelled',
        currency: 'usd',
        stripe_charge_id: "cancellation_#{cancelled_subscription.id}",
        error_message: 'Subscription cancelled by user'
      )

      flash[:notice] = "Your subscription has been cancelled and will not renew. You'll continue to have Pro access until #{Time.at(cancelled_subscription.current_period_end).strftime('%B %d, %Y')}."
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error during cancellation: #{e.message}"
      flash[:alert] = 'Unable to cancel subscription. Please try again or contact support.'
    rescue StandardError => e
      Rails.logger.error "Error during subscription cancellation: #{e.message}"
      flash[:alert] = 'An unexpected error occurred. Please contact support.'
    end
    
    redirect_to manage_subscription_path
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to series_index_path, alert: 'You are not authorized to view payments.'
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :currency, :status, :user_id, :stripe_charge_id, :error_message, :metadata)
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

  def get_user_subscription_info(user)
    return nil unless user&.pro?

    begin
      # Find all subscriptions for this user
      customer_search = Stripe::Customer.search({
        query: "email:'#{user.email}'"
      })

      return nil if customer_search.data.empty?

      customer = customer_search.data.first
      subscriptions = Stripe::Subscription.list({
        customer: customer.id,
        status: 'all',
        limit: 10
      })

      # Find the active or most recent subscription
      active_subscription = subscriptions.data.find { |sub| %w[active trialing].include?(sub.status) }
      subscription = active_subscription || subscriptions.data.first

      return nil unless subscription

      # Debug log the subscription object structure
      Rails.logger.debug "Subscription object: #{subscription.to_hash.inspect}" if Rails.env.development?

      # Extract period information - try subscription level first, then subscription item
      subscription_item = subscription.items.data.first
      
      # Determine current period dates
      period_start = nil
      period_end = nil
      
      # Try to get from subscription item first
      if subscription_item&.current_period_start
        period_start = Time.at(subscription_item.current_period_start)
      end
      
      if subscription_item&.current_period_end
        period_end = Time.at(subscription_item.current_period_end)
      end
      
      # If not found in item, try alternative approaches
      if period_start.nil? && subscription.respond_to?(:billing_cycle_anchor) && subscription.billing_cycle_anchor
        period_start = Time.at(subscription.billing_cycle_anchor)
      end
      
      if period_end.nil? && subscription.respond_to?(:cancel_at) && subscription.cancel_at
        period_end = Time.at(subscription.cancel_at)
      end
      
      {
        subscription_id: subscription.id,
        status: subscription.status,
        amount: subscription_item&.price&.unit_amount || 0,
        currency: subscription_item&.price&.currency || 'usd',
        interval: subscription_item&.price&.recurring&.interval || 'month',
        current_period_start: period_start,
        current_period_end: period_end,
        cancel_at_period_end: subscription.cancel_at_period_end,
        cancelled_at: subscription.canceled_at ? Time.at(subscription.canceled_at) : nil,
        created: subscription.created ? Time.at(subscription.created) : nil
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Error fetching subscription info for user #{user.email}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error fetching subscription info for user #{user.email}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      nil
    end
  end

  # Webhook event handlers
  def handle_checkout_completed(session)
    user = User.find_by(id: session.client_reference_id)
    return unless user

    # Check if payment record already exists to prevent duplicates
    existing_payment = Payment.find_by(stripe_charge_id: session.id)
    return if existing_payment&.completed?

    # Only create payment record if session shows successful payment
    if session.payment_status == 'paid'
      Payment.create!(
        user: user,
        amount: (session.amount_total || 0) / 100.0,
        status: 'completed',
        currency: session.currency || 'usd',
        stripe_charge_id: session.id
      )
      
      # Clean up cache
      Rails.cache.delete("checkout_session_#{session.id}")
    end
    
    Rails.logger.info "Checkout completed for user #{user.email}"
  end

  def handle_subscription_created(subscription)
    customer = Stripe::Customer.retrieve(subscription.customer)
    user = User.find_by(email: customer.email)
    return unless user

    # Update user role only if subscription is active
    if subscription.status == 'active'
      user.update!(role: 'pro') unless user.pro?
      
      # Create payment record only for active subscriptions
      Payment.create!(
        user: user,
        amount: (subscription.plan&.amount || 0) / 100.0,
        status: 'completed',
        currency: subscription.plan&.currency || 'usd',
        stripe_charge_id: subscription.latest_invoice || subscription.id
      )
      
      Rails.logger.info "Active subscription created for user #{user.email}"
    else
      Rails.logger.info "Non-active subscription created for user #{user.email} with status: #{subscription.status}"
    end
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

    # Downgrade user to free when subscription is actually deleted
    if user.pro?
      user.update!(role: 'free')
      
      # Record the downgrade in payments table
      Payment.create!(
        user: user,
        amount: 0.01, # Small amount to satisfy validation
        status: 'cancelled',
        currency: 'usd',
        stripe_charge_id: "subscription_deleted_#{subscription.id}",
        error_message: 'Subscription deleted - user downgraded to free'
      )
      
      Rails.logger.info "User #{user.email} downgraded to free due to subscription deletion"
    end
  end

  def handle_payment_succeeded(invoice)
    customer = Stripe::Customer.retrieve(invoice.customer)
    user = User.find_by(email: customer.email)
    return unless user

    # Check if payment record already exists to prevent duplicates
    existing_payment = Payment.find_by(stripe_charge_id: invoice.id)
    return if existing_payment

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

    # Only record failed payments if there was an actual payment attempt
    # (amount_due > 0 indicates a real payment was attempted)
    if invoice.amount_due && invoice.amount_due > 0
      # Check if payment record already exists to prevent duplicates
      existing_payment = Payment.find_by(stripe_charge_id: invoice.id)
      return if existing_payment

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
