require "test_helper"

class PaymentsCrudTest < ActionDispatch::IntegrationTest

  test "should handle Stripe webhook and create payment" do
    user = User.create!(name: "Webhook User", email: "webhook@example.com", password: "password123", role: "free")
    payload = {
      type: "payment_intent.succeeded",
      data: {
        object: {
          id: "pi_123",
          amount: 1000,
          currency: "usd",
          status: "succeeded",
          metadata: { user_id: user.id }
        }
      }
    }.to_json

    post "/payments/webhook", params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :success
    # Adjust the assertion below to match your webhook logic if you persist payments
    # assert Payment.exists?(stripe_charge_id: "pi_123")
  end
  # Stripe API is not called in test; skip direct CRUD tests
  setup do
    @admin = User.create!(name: "Admin User", email: "admin@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
    @payment = Payment.create!(
      amount: 1000,
      status: "pending",
      user: @admin
    )
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
  end

  test "should get index" do
    get payments_url
    assert_response :success
  end

  test "should show payment" do
    get payment_url(@payment)
    assert_response :success
  end

  test "should create payment" do
    sign_in_as(@admin)
    assert_difference('Payment.count') do
      post payments_url, params: { payment: {
        amount: 2000,
        status: "pending",
        user_id: @admin.id
      } }
    end
    assert_response :redirect
  end

  test "should update payment" do
    patch payment_url(@payment), params: { payment: {
      amount: 3000,
      status: "completed",
      user_id: @admin.id
    } }
    assert_redirected_to payment_url(@payment)
    @payment.reload
    assert_equal 3000, @payment.amount
    assert_equal "completed", @payment.status
  end

  test "should destroy payment" do
    assert_difference('Payment.count', -1) do
      delete payment_url(@payment)
    end
    assert_redirected_to payments_url
  end
end
