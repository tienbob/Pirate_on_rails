# frozen_string_literal: true

class StripeService
  class << self
    def create_checkout_session(user, price, token)
      Stripe::Checkout::Session.create({
        mode: "subscription",
        customer_email: user.email,
        client_reference_id: user.id.to_s,
        metadata: {
          user_id: user.id,
          user_email: user.email,
          success_token: token
        },
        line_items: [ {
          quantity: 1,
          price: price
        } ],
        success_url: success_payments_url(token: token, popup: "true"),
        cancel_url: cancel_payment_url(popup: "true"),
        allow_promotion_codes: true,
        billing_address_collection: "required",
        payment_method_types: [ "card" ]
      })
    end

    def create_portal_session(user, session_id)
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)

      unless checkout_session.client_reference_id == user.id.to_s
        raise "Unauthorized access to billing portal"
      end

      Stripe::BillingPortal::Session.create({
        customer: checkout_session.customer,
        return_url: success_payments_url
      })
    end

    def process_webhook_event(payload, sig_header, webhook_secret)
      Rails.logger.info "Processing webhook event..."
      Rails.logger.info "Webhook secret configured: #{webhook_secret.present?}"
      Rails.logger.info "Signature header present: #{sig_header.present?}"

      event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      Rails.logger.info "Event constructed successfully: #{event.type}"

      StripeWebhookHandler.process(event)
      Rails.logger.info "Event processed successfully"
      { success: true }
    rescue Stripe::SignatureVerificationError, JSON::ParserError => e
      Rails.logger.error "Webhook signature/parsing error: #{e.message}"
      Rails.logger.error "Signature header: #{sig_header}"
      Rails.logger.error "Payload length: #{payload&.length}"
      { success: false, error: :bad_request }
    rescue StandardError => e
      Rails.logger.error "Unexpected webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      { success: false, error: :internal_server_error }
    end

    def verify_and_retrieve_session(token)
      # Retrieve session ID from secure token
      session_id = Rails.cache.read("success_token_#{token}")
      return { success: false, error: "Invalid or expired security token" } unless session_id

      # Clean up the token (one-time use)
      Rails.cache.delete("success_token_#{token}")

      session = Stripe::Checkout::Session.retrieve(session_id)

      # Verify the token matches what we stored in metadata
      unless session.metadata["success_token"] == token
        return { success: false, error: "Security token mismatch" }
      end

      # Find the user from the session data
      user = User.find_by(id: session.client_reference_id)
      return { success: false, error: "User not found" } unless user

      {
        success: true,
        session_data: {
          session_id: session_id,
          payment_status: session.payment_status,
          amount_total: session.amount_total,
          currency: session.currency
        },
        user: user
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe success page error: #{e.message}"
      { success: false, error: "Payment verification failed. Please contact support." }
    rescue StandardError => e
      Rails.logger.error "Unexpected error in session verification: #{e.message}"
      { success: false, error: "An unexpected error occurred. Please contact support." }
    end

    private

    def success_payments_url(params = {})
      Rails.application.routes.url_helpers.success_payments_url(
        params.merge(host: default_host, protocol: default_protocol)
      )
    end

    def cancel_payment_url
      Rails.application.routes.url_helpers.cancel_payment_url(
        host: default_host, protocol: default_protocol
      )
    end

    def default_host
      Rails.application.config.action_mailer.default_url_options[:host] ||
      ENV["HOST"] ||
      "localhost:3000"
    end

    def default_protocol
      Rails.application.config.force_ssl ? "https" : "http"
    end
  end
end
