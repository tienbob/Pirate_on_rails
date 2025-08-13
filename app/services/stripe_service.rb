# frozen_string_literal: true

class StripeService
  def self.create_checkout_session(user, price, token)
    Stripe::Checkout::Session.create({
      mode: 'subscription',
      customer_email: user.email,
      client_reference_id: user.id.to_s,
      metadata: {
        user_id: user.id,
        user_email: user.email,
        success_token: token
      },
      line_items: [{
        quantity: 1,
        price: price
      }],
      success_url: Rails.application.routes.url_helpers.success_payments_url + "?token=#{token}",
      cancel_url: Rails.application.routes.url_helpers.cancel_payment_url,
      allow_promotion_codes: true,
      billing_address_collection: 'required',
      payment_method_types: ['card']
    })
  end

  def self.create_portal_session(user, session_id)
    checkout_session = Stripe::Checkout::Session.retrieve(session_id)

    unless checkout_session.client_reference_id == user.id.to_s
      raise "Unauthorized access to billing portal"
    end

    Stripe::BillingPortal::Session.create({
      customer: checkout_session.customer,
      return_url: Rails.application.routes.url_helpers.upgrade_payment_url
    })
  end
end
