content = File.read("app/controllers/api/rental_lifecycle_controller.rb")

new_method = <<~RUBY
  def capture_damage_amount(rental, amount, damage_amount)
    security_payment = Payment.find_by(rental_id: rental.id, payment_type: 'security_deposit')
    if security_payment && security_payment.authorization_id.present?
      begin
        Rails.logger.info "[Razorpay API] Capturing damage amount for rental \#{rental.id}"
        capture = Razorpay::Payment.capture(security_payment.authorization_id, { amount: amount.security_amount * 100 })
        
        full_capture = Payment.create(
          payment_id: capture.id,
          authorization_id: security_payment.authorization_id,
          capture_id: capture.id,
          status: 'captured',
          amount: capture.amount,
          payment_type: 'full_capture',
          rental_id: rental.id
        )
        
        security_payment.update(
          capture_id: capture.id,
          status: 'full capture security'
        )

        partial_capture = Razorpay::Payment.fetch(security_payment.authorization_id)
        refund = partial_capture.refund(amount: damage_amount * 100)
        
        true
      rescue => e
        Rails.logger.error "[Razorpay API] Failed to capture damage amount for rental \#{rental.id}: \#{e.message}"
        Rails.logger.error "Failed to capture damage: \#{e.message}"
        false
      end
    else
      false
    end
  end
RUBY

content = content.sub(/def capture_damage_amount\(rental, amount\).*?end\n  end/m, new_method + "\n")
File.write("app/controllers/api/rental_lifecycle_controller.rb", content)
