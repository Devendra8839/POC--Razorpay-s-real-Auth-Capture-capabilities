class AdminController < ApplicationController
  def index
    @rentals_count = Rental.count
    @payments_count = Payment.count
    @active_rentals = Rental.where(status: 'active').count
    @completed_rentals = Rental.where(status: 'completed').count
    @recent_rentals = Rental.includes(:product, :renter).order(created_at: :desc).limit(10)
    @recent_payments = Payment.order(created_at: :desc).limit(10)
    @webhook_logs = WebhookLog.order(created_at: :desc).limit(20)
  end
  
  def create_test_rental
    # Create test data
    begin
      # Create seller
      seller = Seller.create!(name: "Test Seller #{rand(1000)}")
      
      # Create product
      product = Product.create!(
        seller: seller,
        name: "Test Product #{rand(1000)}",
        per_day_rent: 10000, # ₹10,000 per day
        security_deposit: 30000 # ₹30,000 security deposit
      )
      
      # Create renter
      renter = User.create!(
        name: "Test Renter #{rand(1000)}",
        email: "renter#{rand(1000)}@example.com"
      )
      
      # Create rental
      rental = Rental.create!(
        product: product,
        renter: renter,
        days: 2,
        rental_amount: 20000, # ₹20,000 for 2 days
        security_amount: 30000, # ₹30,000 security deposit
        status: 'requested'
      )
      
      render json: { success: true, rental_id: rental.id }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  def clear_test_data
    begin
      # Clear all data
      Payment.delete_all
      Rental.delete_all
      Product.delete_all
      Seller.delete_all
      User.delete_all
      WebhookLog.delete_all
      
      render json: { success: true }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
