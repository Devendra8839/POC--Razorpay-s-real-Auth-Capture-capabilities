class Rental < ApplicationRecord
  include RazorpayLogging
  
  belongs_to :product
  belongs_to :renter, class_name: 'User'
  has_many :payments
  
  enum :status, { requested: 'requested', payment_pending: 'payment_pending', rental_paid: 'rental_paid', authorized: 'authorized', active: 'active', returned: 'returned', completed: 'completed', damage: 'damage', unreturned: 'unreturned' }
  
  def log_razorpay_event
    log_entry = {
      event: "rental_status_changed_to_#{status}",
      rental_id: id,
      product_id: product_id,
      renter_id: renter_id,
      rental_amount: rental_amount,
      security_amount: security_amount,
      order_id: order_id,
      security_order_id: security_order_id
    }
    
    Rails.logger.info "[Razorpay Rental Event] #{log_entry.to_json}"
  end
end
