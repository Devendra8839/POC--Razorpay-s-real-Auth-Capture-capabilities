class Api::RentalLifecycleController < ApplicationController
  # Transition rental to next status
  def transition
    # Find the rental ID from the route parameter
    rental_id = params[:rental_id]
    
    if rental_id.blank?
      return render json: { error: 'Rental ID is required' }, status: :bad_request
    end
    
    rental = Rental.find(rental_id)
    
    # Handle both top-level and nested parameters
    param_source = params[:rental_lifecycle] || params
    new_status = param_source[:status]
    damage_amount = param_source[:damage_amount]
    
    # Validate required parameters
    if new_status.blank?
      return render json: { error: 'Status parameter is required' }, status: :bad_request
    end
    
    if new_status == 'damage' && damage_amount.blank?
      return render json: { error: 'Damage amount is required for damage status' }, status: :bad_request
    end
    
    # Validate status transition
    if valid_transition?(rental.status, new_status)
      rental.update(status: new_status)
      
      # Handle specific transitions
      case new_status
      when 'authorized'
        # Security deposit has been authorized
        handle_authorized(rental)
      when 'active'
        # Item has been delivered, rental is active
        handle_active(rental)
      when 'returned'
        # Item has been returned
        handle_returned(rental)
      when 'completed'
        # Rental completed successfully
        handle_completed(rental)
      when 'damage'
        # Damage reported
        handle_damage(rental, damage_amount)
      when 'unreturned'
        # Item not returned
        handle_unreturned(rental)
      end
      
      render json: { success: true, rental: rental }
    else
      # Special case: if already in damage status and trying to report damage again,
      # allow updating the damage amount
      if rental.status == 'damage' && new_status == 'damage' && damage_amount.present?
        handle_damage(rental, damage_amount)
        return render json: { success: true, rental: rental }
      end
      
      render json: { error: "Invalid status transition from #{rental.status} to #{new_status}" }, status: :bad_request
    end
  end
    def admin_capture_damage
    rental = Rental.find(params[:rental_id])
    binding.irb
    # if rental.status == 'damage' && rental.damage_amount.to_i > 0
      if capture_damage_amount(rental, rental.damage_amount)
        rental.update(status: 'completed')
        render json: { success: true, message: 'Damage captured successfully, remainder refunded automatically.' }
      else
        render json: { error: 'Failed to capture damage from Razorpay.' }, status: :internal_server_error
      end
    # else
    #   render json: { error: 'Invalid state or no damage amount recorded.' }, status: :bad_request
    # end
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

  private
  
  def valid_transition?(current_status, new_status)
    # Define valid state transitions
    valid_transitions = {
      'requested' => ['payment_pending'],
      'payment_pending' => ['rental_paid'],
      'rental_paid' => ['authorized'],
      'authorized' => ['active'],
      'active' => ['returned', 'damage', 'unreturned'],
      'returned' => ['completed'],
      'damage' => ['completed'],
      'unreturned' => ['completed']
    }
    
    valid_transitions[current_status.to_sym]&.include?(new_status) || false
  end
  
  def handle_authorized(rental)
    # Security deposit has been authorized
    # Update rental status and log the event
    Rails.logger.info "Rental #{rental.id} security deposit authorized"
  end
  
  def handle_active(rental)
    # Item delivered, rental is now active
    Rails.logger.info "Rental #{rental.id} is now active"
  end
  
  def handle_returned(rental)
    # Item returned, release security deposit
    release_security_deposit(rental)
    Rails.logger.info "Rental #{rental.id} item returned, security deposit released"
  end
  
  def handle_completed(rental)
    # Rental completed
    Rails.logger.info "Rental #{rental.id} completed successfully"
  end
  
  def handle_damage(rental, damage_amount)
    # Save damage amount for admin review, do not capture yet
    rental.update(damage_amount: damage_amount.to_i)
    Rails.logger.info "Rental #{rental.id} damage reported: #{damage_amount}"
  end
  
  def handle_unreturned(rental)
    # Capture full security deposit
    capture_full_security(rental)
    Rails.logger.info "Rental #{rental.id} item not returned, full security captured"
  end
  
  def release_security_deposit(rental)
    # Find the security deposit payment
    security_payment = Payment.find_by(rental_id: rental.id, payment_type: 'security_deposit')
    
    if security_payment && security_payment.authorization_id.present?
      # Release the authorization (refund)
      begin
        Rails.logger.info "[Razorpay API] Releasing security deposit for rental #{rental.id}"
        
        refund = Razorpay::Payment.refund(security_payment.authorization_id, {
          amount: security_payment.amount
        })
        
        security_payment.update(
          refund_id: refund.id,
          status: 'refunded'
        )
        
        # Log successful API call
        security_payment.log_api_call('POST', "payments/#{security_payment.authorization_id}/refund", {
          amount: security_payment.amount
        }, refund.as_json, true)
        
        true
      rescue => e
        # Log failed API call
        Rails.logger.error "[Razorpay API] Failed to release security deposit for rental #{rental.id}: #{e.message}"
        
        Rails.logger.error "Failed to release security deposit: #{e.message}"
        false
      end
    else
      false
    end
  end
  
  def capture_damage_amount(rental, amount)
    # Find the security deposit payment
    security_payment = Payment.find_by(rental_id: rental.id, payment_type: 'security_deposit')
    
    if security_payment && security_payment.authorization_id.present?
      # Capture the damage amount
      begin
        Rails.logger.info "[Razorpay API] Capturing damage amount for rental #{rental.id}"
        
        capture = Razorpay::Payment.capture(security_payment.authorization_id, { amount: amount * 100 })
        
        # Create damage capture payment record
        damage_payment = Payment.create(
          payment_id: capture.id,
          authorization_id: security_payment.authorization_id,
          capture_id: capture.id,
          status: 'captured',
          amount: capture.amount,
          payment_type: 'damage_capture',
          rental_id: rental.id
        )
        
        # Update original security payment
        security_payment.update(
          capture_id: capture.id,
          status: 'partially_captured'
        )
        
        # Log successful API call
        damage_payment.log_api_call('POST', "payments/#{security_payment.authorization_id}/capture", {
          amount: amount * 100
        }, capture.as_json, true)
        
        true
      rescue => e
        # Log failed API call
        Rails.logger.error "[Razorpay API] Failed to capture damage amount for rental #{rental.id}: #{e.message}"
        
        Rails.logger.error "Failed to capture damage amount: #{e.message}"
        false
      end
    else
      false
    end
  end
  
  def capture_full_security(rental)
    # Find the security deposit payment
    security_payment = Payment.find_by(rental_id: rental.id, payment_type: 'security_deposit')
    
    if security_payment && security_payment.authorization_id.present?
      # Capture the full security amount
      begin
        Rails.logger.info "[Razorpay API] Capturing full security for rental #{rental.id}"
        
        capture = Razorpay::Payment.capture(security_payment.authorization_id, { amount: security_payment.amount })
        
        # Update payment record
        security_payment.update(
          capture_id: capture.id,
          status: 'captured',
          payment_type: 'full_capture'
        )
        
        # Log successful API call
        security_payment.log_api_call('POST', "payments/#{security_payment.authorization_id}/capture", {
          amount: security_payment.amount
        }, capture.as_json, true)
        
        true
      rescue => e
        # Log failed API call
        Rails.logger.error "[Razorpay API] Failed to capture full security for rental #{rental.id}: #{e.message}"
        
        Rails.logger.error "Failed to capture full security: #{e.message}"
        false
      end
    else
      false
    end
  end
end
