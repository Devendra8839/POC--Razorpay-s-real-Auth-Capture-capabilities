class Api::PaymentsController < ApplicationController
  before_action :set_payment, only: [:show, :update, :destroy]
  
  # GET /api/payments
  def index
    @payments = Payment.all
    render json: @payments
  end
  
  # GET /api/payments/1
  def show
    render json: @payment
  end
  
  # POST /api/payments
  def create
    @payment = Payment.new(payment_params)
    
    if @payment.save
      render json: @payment, status: :created
    else
      render json: @payment.errors, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/payments/1
  def update
    if @payment.update(payment_params)
      render json: @payment
    else
      render json: @payment.errors, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/payments/1
  def destroy
    @payment.destroy
    head :no_content
  end
  
  # Create Razorpay order
  def create_order
    rental = Rental.find(params[:rental_id])
    rental.update!(rental_amount: params[:dynamic_amount].to_i) if params[:dynamic_amount].present?
    
    begin
      # Log API call
      Rails.logger.info "[Razorpay API] Creating order for rental #{rental.id}"
      
      # Create Razorpay order for rental amount
      razorpay_order = Razorpay::Order.create(
        amount: rental.rental_amount * 100, # Razorpay uses paise
        currency: 'INR',
        receipt: "rental_#{rental.id}",
        payment_capture: 1 # Auto capture for rental payment
      )
      
      # Store order ID in rental
      # binding.irb
      rental.update(order_id: razorpay_order.id)
      
      # Log successful API call
      rental.log_api_call('POST', 'orders', {
        amount: rental.rental_amount * 100,
        currency: 'INR',
        receipt: "rental_#{rental.id}",
        payment_capture: 1
      }, razorpay_order.as_json, true)
      
      render json: {
        order_id: razorpay_order.id,
        amount: razorpay_order.amount,
        currency: razorpay_order.currency
      }
    rescue => e
      # Log failed API call
      Rails.logger.error "[Razorpay API] Failed to create order for rental #{rental.id}: #{e.message}"
      
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  # Capture payment immediately
  def capture_payment
    payment_id = params[:payment_id]
    amount = params[:amount].to_i * 100 # Convert to paise
    
    begin
      # Log API call
      Rails.logger.info "[Razorpay API] Capturing payment #{payment_id}"
      
      # Capture the payment
      payment = Razorpay::Payment.fetch(payment_id)
      payment = Razorpay::Payment.capture(payment_id, { amount: amount }) if payment.status != "captured"
      
      # Create payment record
      payment_record = Payment.create(
        payment_id: payment.id,
        order_id: payment.order_id,
        status: 'captured',
        amount: payment.amount,
        payment_type: 'rental_payment',
        payment_method: payment.method,
        rental_id: Rental.find_by(order_id: payment.order_id)&.id
      )
      
      # Log successful API call
      # Update rental status
      rental = Rental.find_by(order_id: payment.order_id)
      rental.update(status: "rental_paid") if rental
      payment_record.log_api_call('POST', "payments/#{payment_id}/capture", {
        amount: amount
      }, payment.as_json, true)
      
      render json: { success: true, payment: payment }
    rescue => e
      # Log failed API call
      Rails.logger.error "[Razorpay API] Failed to capture payment #{payment_id}: #{e.message}"
      
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  # Authorize security deposit (don't capture)
  def sync_security_authorization
  payment = Payment.find_by(rental_id: params[:rental_id], payment_type: 'security_deposit')
  if payment
    payment.update!(authorization_id: params[:payment_id], status: 'authorized')
    rental = payment.rental
    rental.update!(status: 'authorized') if rental.status == 'rental_paid'
    render json: { success: true }
  else
    render json: { error: 'Payment not found' }, status: :not_found
  end
end


  def authorize_security
    rental = Rental.find(params[:rental_id])
    rental.update!(security_amount: params[:dynamic_amount].to_i) if params[:dynamic_amount].present?
    
    begin
      # Log API call
      Rails.logger.info "[Razorpay API] Creating security authorization order for rental #{rental.id}"
      
      # Create Razorpay order for security deposit with capture disabled
      razorpay_order = Razorpay::Order.create(
        amount: rental.security_amount * 100, # Razorpay uses paise
        currency: 'INR',
        receipt: "security_#{rental.id}",
        payment_capture: 0 # Don't auto capture - authorize only
      )
      
      # Store authorization order ID
      rental.update(security_order_id: razorpay_order.id)
      
      # Create payment record for the authorization
      payment_record = Payment.create(
        order_id: razorpay_order.id,
        status: 'pending',
        amount: razorpay_order.amount,
        payment_type: 'security_deposit',
        rental_id: rental.id
      )
      
      # Log successful API call
      rental.log_api_call('POST', 'orders', {
        amount: rental.security_amount * 100,
        currency: 'INR',
        receipt: "security_#{rental.id}",
        payment_capture: 0
      }, razorpay_order.as_json, true)
      
      render json: {
        order_id: razorpay_order.id,
        amount: razorpay_order.amount,
        currency: razorpay_order.currency
      }
    rescue => e
      # Log failed API call
      Rails.logger.error "[Razorpay API] Failed to create security authorization for rental #{rental.id}: #{e.message}"
      
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  # Capture from authorization
  def capture_authorization
    authorization_id = params[:authorization_id]
    amount = params[:amount].to_i * 100 # Convert to paise
    
    begin
      # Capture the authorized amount
      capture = Razorpay::Payment.capture(authorization_id, { amount: amount })
      
      # Update payment record
      payment = Payment.find_by(authorization_id: authorization_id)
      payment.update(
        capture_id: capture.id,
        status: 'captured',
        amount: capture.amount
      )
      
      render json: { success: true, capture: capture }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  # Release authorization (void)
  def release_authorization
    authorization_id = params[:authorization_id]
    
    begin
      # This would typically be a refund or void operation
      # Razorpay may not support true authorization void, so we might need to refund
      refund = Razorpay::Payment.refund(authorization_id, {
        amount: params[:amount].to_i * 100
      })
      
      # Update payment record
      payment = Payment.find_by(authorization_id: authorization_id)
      payment.update(
        refund_id: refund.id,
        status: 'refunded'
      )
      
      render json: { success: true, refund: refund }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_payment
      @payment = Payment.find(params[:id])
    end
    
    # Only allow a list of trusted parameters through.
    def payment_params
      params.require(:payment).permit(:payment_id, :order_id, :authorization_id, :capture_id, :refund_id, :status, :amount, :payment_type, :payment_method)
    end
end
