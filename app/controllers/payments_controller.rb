require 'ostruct'

class PaymentsController < ApplicationController
  protect_from_forgery except: [:webhook]
  before_action :authenticate_user!, except: [:webhook, :success]
  before_action :require_admin, only: [:index]
  before_action :set_payment, only: [:show]
  before_action :check_rate_limit, except: [:webhook, :success, :manage_subscription, :cancel_subscription, :index, :show]

  # Admin: List all payments
  def index
    @payment_stats = PaymentService.get_payment_statistics
    @payments = PaymentService.get_paginated_payments(params[:page])
  end

  # Show payment details (admin or payment owner)
  def show
    unless current_user.admin? || @payment.user == current_user
      redirect_to series_index_path, alert: 'You are not authorized to view this payment.'
      return
    end
  end

  # Stripe Checkout Session for subscription
  def create_checkout_session
    unless params[:price].present?
      render json: { error: { message: "Missing or empty price parameter (Stripe Price ID)." } }, 
             status: :bad_request
      return
    end

    unless params[:price].match?(/^price_[a-zA-Z0-9]+$/)
      render json: { error: { message: "Invalid price ID format." } }, 
             status: :bad_request
      return
    end

    begin
      token = SecureRandom.urlsafe_base64(32)
      session = StripeService.create_checkout_session(current_user, params[:price], token)

      # Cache session details for later reference
      Rails.cache.write("checkout_session_#{session.id}", {
        user_id: current_user.id,
        price_id: params[:price],
        success_token: token,
        created_at: Time.current
      }, expires_in: 1.hour)
      
      # Also store token mapping to session ID for security
      Rails.cache.write("success_token_#{token}", session.id, expires_in: 1.hour)
      
      # Check if this is an AJAX request for popup
      if request.xhr? || params[:popup] == 'true'
        render json: { 
          success: true, 
          checkout_url: session.url,
          session_id: session.id
        }
      else
        redirect_to session.url, allow_other_host: true
      end

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
      portal_session = StripeService.create_portal_session(current_user, params[:session_id])
      redirect_to portal_session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      flash[:alert] = 'Unable to access billing portal. Please try again.'
      redirect_to upgrade_payment_path
    end
  end

  # Stripe Webhook endpoint with proper security
  def webhook
    Rails.logger.info "=== WEBHOOK RECEIVED ==="
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Webhook received: #{request.headers['HTTP_STRIPE_SIGNATURE'].present? ? 'with signature' : 'WITHOUT signature'}"
    Rails.logger.info "Request body size: #{request.body.size}"
    Rails.logger.info "Raw headers: #{request.headers.select { |k, v| k.start_with?('HTTP_') }.to_h}"
    
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']  # Use environment variable

    Rails.logger.info "Webhook secret present: #{webhook_secret.present?}"
    Rails.logger.info "Payload preview: #{payload[0..100]}..." if payload.length > 0

    result = StripeService.process_webhook_event(payload, sig_header, webhook_secret)
    
    if result[:success]
      Rails.logger.info "Webhook processed successfully"
      render json: { status: 'success' }
    else
      Rails.logger.error "Webhook processing failed: #{result[:error]}"
      case result[:error]
      when :bad_request
        head :bad_request
      when :internal_server_error
        render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
      end
    end
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

    result = StripeService.verify_and_retrieve_session(params[:token])
    
    unless result[:success]
      flash[:alert] = result[:error]
      redirect_to series_index_path
      return
    end

    payment_result = PaymentService.process_successful_payment(result[:session_data], result[:user])
    
    if payment_result[:already_processed]
      unless user_signed_in? && current_user.id == result[:user].id
        sign_in(result[:user])
        Rails.logger.info "User #{result[:user].email} automatically signed in after payment success (existing payment)"
      end
      flash[:notice] = "Your account is already upgraded!"
    else
      flash[:notice] = payment_result[:message]
      
      # Sign in user AFTER successful transaction
      unless user_signed_in? && current_user.id == result[:user].id
        sign_in(result[:user])
        Rails.logger.info "User #{result[:user].email} automatically signed in after payment success"
      end
    end

    # Check if this is a popup request (from Stripe checkout)
    # If it's a popup, render the success page to handle popup closure
    # If it's not a popup, redirect directly to series index
    if request.headers['HTTP_REFERER']&.include?('checkout.stripe.com') || params[:popup] == 'true'
      # This is likely from a popup - render the success page
      render :success
    else
      # Direct access - redirect to series index
      redirect_to series_index_path
    end
  end

  def cancel
    # Check if this is a popup request (from Stripe checkout)
    if request.headers['HTTP_REFERER']&.include?('checkout.stripe.com') || params[:popup] == 'true'
      # This is likely from a popup - render the cancel page
      render :cancel
    else
      # Direct access - redirect to series index
      redirect_to series_index_path, alert: 'Payment was canceled.'
    end
  end

  # Subscription management page for Pro users
  def manage_subscription
    unless current_user&.pro?
      redirect_to series_index_path, alert: 'You do not have an active subscription.'
      return
    end

    begin
      # Get most recent checkout session ID for billing portal access
      @checkout_session_id = Rails.cache.fetch("user_#{current_user.id}_checkout_session", expires_in: 20.minutes) do
        Payment.where(user: current_user, status: 'completed')
               .order(created_at: :desc)
               .limit(1)
               .pluck(:stripe_charge_id)
               .first
      end

      @subscription_info = SubscriptionService.get_subscription_with_fallback(current_user)
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error in manage_subscription: #{e.message}"
      
      # Show page with cached data or dynamic fallback
      @subscription_info = Rails.cache.fetch("subscription_info:#{current_user.id}") || 
                          SubscriptionService.send(:generate_dynamic_fallback_data, current_user)
      
      Rails.logger.info "Used fallback data due to Stripe error for user: #{current_user.email}"
    end
  end

  # Cancel user's subscription
  def cancel_subscription
    unless current_user&.pro?
      redirect_to series_index_path, alert: 'You do not have an active subscription.'
      return
    end

    result = PaymentService.cancel_user_subscription(current_user)
    
    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end
    
    redirect_to manage_subscription_path
  end

  # Manual sync with Stripe (for testing/debugging)
  def manual_sync
    unless current_user&.admin?
      redirect_to series_index_path, alert: 'Not authorized.'
      return
    end

    user_id = params[:user_id] || current_user.id
    user = User.find(user_id)
    
    result = StripeManualSyncService.sync_user_subscription(user)
    
    if result[:success]
      flash[:notice] = "Manual sync completed: #{result[:message]}"
    else
      flash[:alert] = "Manual sync failed: #{result[:message]}"
    end
    
    redirect_back(fallback_location: series_index_path)
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
    result = PaymentService.check_rate_limit(request, current_user)
    
    if result[:exceeded]
      flash[:alert] = result[:message]
      redirect_to series_index_path
    end
  end
end
