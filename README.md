# Razorpay Auth & Capture POC for P2P Rental Marketplace

## Overview

This is a Proof of Concept (POC) application to test and validate Razorpay's **Card Authorization (Pre-Authorization / Auth & Capture)** capabilities for a peer-to-peer rental marketplace.

The POC demonstrates a complete rental payment flow where:
- Rental amount is captured immediately
- Security deposit is authorized (held) but not captured
- Authorization can be released or partially/full captured based on rental outcome

## Tech Stack

- **Ruby on Rails 8.0.5** (API mode)
- **SQLite** (for development, easily switchable to PostgreSQL)
- **Razorpay Ruby Gem** (v3.2.4)
- **Razorpay Test Mode**
- **Razorpay Webhooks**
- **Stimulus/Plain JavaScript** frontend

## Setup Instructions

### Prerequisites

- Ruby 3.3.3
- Rails 8.0.5
- SQLite (or PostgreSQL if you prefer)
- Bundler
- Node.js (for asset compilation)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/your-repo/razorpay-rental-poc.git
cd razorpay-rental-poc
```

2. Install dependencies:

```bash
bundle install
```

3. Set up the database:

```bash
rails db:create db:migrate
```

4. Set up Razorpay credentials:

Copy `.env.example` to `.env` and add your Razorpay test credentials:

```env
RAZORPAY_KEY_ID=rzp_test_YourKeyId
RAZORPAY_KEY_SECRET=YourKeySecret
RAZORPAY_WEBHOOK_SECRET=webhook_secret
```

### Running the Application

Start the Rails server:

```bash
rails server
```

The application will be available at `http://localhost:3000`

### Using ngrok for Webhook Testing

To test Razorpay webhooks locally, use ngrok:

```bash
ngrok http 3000
```

Then configure your Razorpay webhook URL to point to `https://your-ngrok-url.ngrok.io/api/razorpay/webhook`

## Application Structure

### Key Components

1. **Models**:
   - `User` - Renters
   - `Seller` - Product owners
   - `Product` - Rental items with pricing
   - `Rental` - Rental transactions with lifecycle
   - `Payment` - Payment records with Razorpay details
   - `WebhookLog` - Razorpay webhook events

2. **Controllers**:
   - `Api::PaymentsController` - Payment processing endpoints
   - `Api::RentalsController` - Rental management
   - `Api::RentalLifecycleController` - Rental status transitions
   - `Api::RazorpayController` - Webhook handling
   - `SellerDashboardController` - Seller interface
   - `CustomerDashboardController` - Customer interface
   - `AdminController` - Admin monitoring

3. **Views**:
   - Seller dashboard with authorization controls
   - Customer dashboard with payment status
   - Admin panel for monitoring

### Rental Lifecycle Statuses

```
Requested → Payment Pending → Rental Paid → Security Authorized → 
Item Delivered → Rental Active → [Returned → Completed]
                              → [Damage Reported → Completed]
                              → [Not Returned → Completed]
```

## Razorpay Integration Details

### Test Cards

Use Razorpay test cards for testing:

- **Success**: `4111 1111 1111 1111` (CVV: any 3 digits, Expiry: any future date)
- **Failure**: `4000 0000 0000 0002`
- **3D Secure**: `4000 0000 0000 0077`

### API Endpoints

#### Payment Processing

- `POST /api/payments/create_order` - Create Razorpay order
- `POST /api/payments/capture_payment` - Capture rental payment
- `POST /api/payments/authorize_security` - Authorize security deposit
- `POST /api/payments/capture_authorization` - Capture from authorization
- `POST /api/payments/release_authorization` - Release authorization

#### Rental Lifecycle

- `POST /api/rentals/:rental_id/transition` - Transition rental status

#### Webhooks

- `POST /api/razorpay/webhook` - Razorpay webhook endpoint

### Webhook Events Handled

- `payment.authorized` - Security deposit authorized
- `payment.captured` - Payment captured
- `payment.failed` - Payment failed
- `refund.processed` - Refund processed
- `order.paid` - Order paid

## Testing the POC

### Scenario 1: Successful Rental Flow

1. **Create Test Rental**: Use the admin panel to create a test rental
2. **Customer Pays Rental**: Customer pays the rental amount (captured immediately)
3. **Customer Authorizes Security**: Customer authorizes security deposit (not captured)
4. **Seller Delivers Item**: Seller marks rental as active
5. **Customer Returns Item**: Seller marks as returned
6. **Seller Completes Rental**: Security deposit is released

### Scenario 2: Damage Reported

1. Follow steps 1-4 above
2. **Seller Reports Damage**: Seller enters damage amount
3. **System Captures Damage Amount**: Partial capture from authorization
4. **Seller Completes Rental**: Remaining authorization is released

### Scenario 3: Item Not Returned

1. Follow steps 1-4 above
2. **Seller Marks Not Returned**: Full security deposit is captured
3. **Seller Completes Rental**: Rental closed with full capture

## Razorpay Auth & Capture Findings

### What Works

✅ **Order Creation with `payment_capture: 0`** - Successfully creates authorization-only orders
✅ **Payment Authorization** - Cards can be authorized without immediate capture
✅ **Webhook Notifications** - `payment.authorized` events are received
✅ **Partial Capture** - Can capture partial amounts from authorization
✅ **Full Capture** - Can capture full authorized amount
✅ **Refunds** - Can refund/release authorizations

### Limitations Found

⚠️ **Authorization Expiry** - Razorpay authorizations typically expire in 7-15 days (varies by bank)
⚠️ **Bank Support** - Not all banks support long-duration authorizations
⚠️ **True Void Missing** - No direct "void" API; must use refund to release
⚠️ **Card Type Restrictions** - Some debit cards may not support authorization

### Recommendations

1. **For Short-Term Rentals** (car rentals, hotel stays):
   - Razorpay Auth & Capture works well
   - Authorization duration is sufficient
   - Implement proper expiration handling

2. **For Long-Term Rentals** (monthly equipment rentals):
   - Consider alternative approaches:
     - Collect full security deposit upfront
     - Use periodic payments instead of long holds
     - Implement manual verification for high-value items

3. **Fallback Mechanism**:
   - Always have a fallback for when authorization fails
   - Clearly communicate to users when authorization isn't supported
   - Provide alternative payment methods

## Configuration

### Razorpay Setup

1. Sign up for Razorpay test account at https://dashboard.razorpay.com/
2. Get your test API keys from Settings > API Keys
3. Configure webhooks in Settings > Webhooks
4. Use test cards for development

### Environment Variables

```env
RAZORPAY_KEY_ID=your_test_key_id
RAZORPAY_KEY_SECRET=your_test_key_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
```

## Deployment

### For Production

1. Switch to PostgreSQL (update `config/database.yml`)
2. Set up proper environment variables
3. Configure HTTPS for webhook security
4. Set up proper authentication
5. Implement rate limiting
6. Add monitoring and alerts

### Scaling Considerations

- Use background jobs for webhook processing
- Implement idempotency for API calls
- Add retry logic for failed operations
- Consider caching for frequently accessed data

## Troubleshooting

### Common Issues

1. **Webhook Signature Verification Failed**:
   - Ensure webhook secret matches
   - Check payload format
   - Verify ngrok URL is correct

2. **Authorization Not Working**:
   - Check if test card supports authorization
   - Verify `payment_capture: 0` is set
   - Check bank support for authorization

3. **Payment Capture Failed**:
   - Ensure authorization is still valid
   - Check capture amount doesn't exceed authorized amount
   - Verify payment ID is correct

### Debugging

- Check Rails logs: `tail -f log/development.log`
- Review webhook logs in admin panel
- Use Razorpay dashboard to verify API calls
- Check database records for payment status

## Conclusion

This POC demonstrates that **Razorpay does support Auth & Capture functionality**, but with some important limitations regarding authorization duration and bank support. The implementation is suitable for short-term rental scenarios but may require alternative approaches for long-term rentals.

The complete rental payment lifecycle has been implemented with proper status management, webhook handling, and comprehensive logging to validate Razorpay's capabilities for a P2P rental marketplace.
