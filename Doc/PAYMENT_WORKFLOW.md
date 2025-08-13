# Payment Workflow Documentation

## Overview
The payment workflow in our application is designed to handle various payment-related operations, including subscription management, one-time payments, and webhook processing. It integrates with Stripe for payment processing and ensures secure and efficient handling of user transactions.

---

## Key Components

### 1. **PaymentsController**
The `PaymentsController` is the central controller for managing payment-related actions. It includes the following key actions:

- **`index`**: Lists all payments for admin users. It uses caching to optimize the retrieval of payment statistics.
- **`show`**: Displays payment details for admins or the payment owner.
- **`create_checkout_session`**: Creates a Stripe Checkout session for subscriptions. It validates the price parameter, generates a secure token, and stores session data in the cache.
- **`create_portal_session`**: Redirects users to the Stripe Billing Portal for managing their subscriptions.
- **`webhook`**: Processes Stripe webhook events securely using the `StripeWebhookHandler` service.
- **`success`**: Handles successful payments by verifying tokens, cleaning up cache, and updating user roles.
- **`manage_subscription`**: Displays subscription details for Pro users, with caching and background refresh mechanisms.
- **`cancel_subscription`**: Cancels a user's subscription and logs the cancellation.

### 2. **StripeService**
The `StripeService` is a service object responsible for interacting with the Stripe API. It handles operations such as creating checkout sessions and managing subscriptions.

### 3. **StripeWebhookHandler**
The `StripeWebhookHandler` processes incoming webhook events from Stripe. It ensures secure verification of events and delegates specific event handling to private methods in the `PaymentsController`.

---

## Workflow Details

### 1. **Subscription Creation**
- The user selects a subscription plan.
- The `create_checkout_session` action in `PaymentsController` is triggered.
- A secure token is generated, and a Stripe Checkout session is created.
- Session details are temporarily stored in the cache.
- The user is redirected to the Stripe-hosted checkout page.

### 2. **Subscription Management**
- Users can access the Stripe Billing Portal via the `create_portal_session` action.
- The portal allows users to update payment methods, cancel subscriptions, or view billing history.

### 3. **Webhook Processing**
- Stripe sends webhook events to the `webhook` endpoint.
- The `StripeWebhookHandler` verifies the event signature and processes the event.
- Supported events include:
  - `checkout.session.completed`: Finalizes the subscription and updates the user's role.
  - `customer.subscription.created`: Logs the creation of a new subscription.
  - `customer.subscription.updated`: Updates subscription details.
  - `customer.subscription.deleted`: Handles subscription cancellations.
  - `invoice.payment_succeeded`: Logs successful payments.
  - `invoice.payment_failed`: Handles failed payments.

### 4. **Payment Success**
- After a successful payment, the `success` action verifies the security token and retrieves the session details.
- The user's role is updated based on the subscription.
- The user is signed in automatically if not already logged in.

### 5. **Subscription Cancellation**
- Users can cancel their subscriptions via the `cancel_subscription` action.
- The subscription is canceled at the end of the current billing period.
- A cancellation record is created for audit purposes.

---

## Caching Strategy
- Payment statistics are cached using namespaced keys (e.g., `payments:stats:v2`) to avoid conflicts.
- Subscription information is cached for 5 minutes to reduce API calls to Stripe.
- Background refreshes are scheduled if the cache is older than 2 minutes.

---

## Error Handling
- Stripe errors are logged and displayed to users with appropriate messages.
- Database transactions ensure data consistency during critical operations.
- Security tokens are used to prevent unauthorized access to payment sessions.

---

## Security Measures
- Webhook events are verified using Stripe's signature header.
- Sensitive data is stored securely in the Rails cache with expiration policies.
- Role synchronization ensures users have the correct access level based on their subscription status.

---

## Future Improvements
- Implement more granular caching for specific payment actions.
- Add support for additional payment gateways.
- Enhance logging and monitoring for payment-related operations.

---

This document provides a comprehensive overview of the payment workflow in our application. For further details, refer to the respective service and controller files.
