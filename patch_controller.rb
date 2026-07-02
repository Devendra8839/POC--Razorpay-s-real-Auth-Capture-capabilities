content = File.read("app/controllers/api/rental_lifecycle_controller.rb")

new_methods = <<~METHODS
  def admin_capture_damage
    rental = Rental.find(params[:rental_id])
    if rental.status == 'damage' && rental.damage_amount.to_i > 0
      if capture_damage_amount(rental, rental.damage_amount)
        rental.update(status: 'completed')
        render json: { success: true, message: 'Damage captured successfully, remainder refunded automatically.' }
      else
        render json: { error: 'Failed to capture damage from Razorpay.' }, status: :internal_server_error
      end
    else
      render json: { error: 'Invalid state or no damage amount recorded.' }, status: :bad_request
    end
  end

  def refund_status
    rental = Rental.find(params[:rental_id])
    security_payment = Payment.find_by(rental_id: rental.id, payment_type: 'security_deposit')
    
    if security_payment.nil? || security_payment.authorization_id.blank?
      return render json: { status: 'No active security hold found.' }
    end
    
    begin
      rzp_payment = Razorpay::Payment.fetch(security_payment.authorization_id)
      
      message = "Status: #{rzp_payment.status}. "
      if rzp_payment.amount_refunded && rzp_payment.amount_refunded > 0
        message += "₹#{rzp_payment.amount_refunded / 100.0} has been refunded. "
      end
      if rzp_payment.status == 'captured'
        amount_captured = rzp_payment.amount - (rzp_payment.amount_refunded || 0)
        message += "₹#{amount_captured / 100.0} was captured."
      end
      
      render json: { status: message }
    rescue => e
      render json: { error: "Failed to fetch status: #{e.message}" }, status: :internal_server_error
    end
  end
METHODS

content = content.sub("private\n", new_methods + "\n  private\n")

File.write("app/controllers/api/rental_lifecycle_controller.rb", content)
