content = File.read("app/controllers/api/payments_controller.rb")

sync_method = <<~RUBY
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

RUBY

content = content.sub(/def authorize_security/, sync_method + "\n  def authorize_security")

File.write("app/controllers/api/payments_controller.rb", content)
