class Payment < ApplicationRecord
  include RazorpayLogging
  
  belongs_to :rental, optional: true
  
  enum :payment_type, %w[
    rental_payment
    security_deposit
    damage_capture
    full_capture
  ]
  
  def log_razorpay_event
    log_entry = {
      event: "payment_#{status}_for_rental_#{rental_id}",
      payment_id: payment_id,
      order_id: order_id,
      amount: amount,
      payment_type: payment_type,
      status: status
    }
    
    Rails.logger.info "[Razorpay Payment Event] #{log_entry.to_json}"
  end
end
