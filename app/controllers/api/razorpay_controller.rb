class Api::RazorpayController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  # Razorpay webhook endpoint
  def webhook
    payload = request.body.read
    signature = request.headers['X-Razorpay-Signature']
    
    # Verify webhook signature
    begin
      Razorpay::Utility.verify_webhook_signature(payload, signature, ENV['RAZORPAY_WEBHOOK_SECRET'] || 'webhook_secret')
      
      event = JSON.parse(payload)
      
      # Log the webhook event
      Rails.logger.info "Razorpay Webhook Received: #{event['event']}"
      
      # Store webhook log in database
      WebhookLog.create(
        event_type: event['event'],
        payload: payload
      )
      
      # Handle different webhook events
      case event['event']
      when 'payment.authorized'
        handle_payment_authorized(event['payload'])
      when 'payment.captured'
        handle_payment_captured(event['payload'])
      when 'payment.failed'
        handle_payment_failed(event['payload'])
      when 'refund.processed'
        handle_refund_processed(event['payload'])
      when 'order.paid'
        handle_order_paid(event['payload'])
      else
        Rails.logger.info "Unhandled webhook event: #{event['event']}"
      end
      
      head :ok
    rescue Razorpay::SignatureVerificationError => e
      Rails.logger.error "Webhook signature verification failed: #{e.message}"
      head :unauthorized
    rescue => e
      Rails.logger.error "Webhook processing error: #{e.message}"
      head :internal_server_error
    end
  end
  
  private
  
  def handle_payment_authorized(payload)
    # Update payment record with authorization details
    payment = Payment.find_by(order_id: payload['payment']['entity']['order_id'])
    
    if payment
      payment.update(
        payment_id: payload['payment']['entity']['id'],
        authorization_id: payload['payment']['entity']['id'],
        status: 'authorized',
        amount: payload['payment']['entity']['amount']
      )
      
      # Update rental status
      rental = Rental.find_by(id: payment.rental_id)
      rental.update(status: 'authorized') if rental
    end
  end
  
  def handle_payment_captured(payload)
    # Update payment record with capture details
    payment = Payment.find_by(payment_id: payload['payment']['entity']['id'])
    
    if payment
      payment.update(
        capture_id: payload['payment']['entity']['id'],
        status: 'captured',
        amount: payload['payment']['entity']['amount']
      )
    end
  end
  
  def handle_payment_failed(payload)
    # Handle failed payment
    payment = Payment.find_by(payment_id: payload['payment']['entity']['id'])
    
    if payment
      payment.update(status: 'failed')
    end
  end
  
  def handle_refund_processed(payload)
    # Handle refund
    payment = Payment.find_by(payment_id: payload['payment']['entity']['id'])
    
    if payment
      payment.update(
        refund_id: payload['refund']['entity']['id'],
        status: 'refunded'
      )
    end
  end
  
  def handle_order_paid(payload)
    # Handle order paid event
    order_id = payload['order']['entity']['id']
    
    # Find rental associated with this order
    rental = Rental.find_by(order_id: order_id)
    
    if rental
      rental.update(status: 'rental_paid')
    end
  end
end
