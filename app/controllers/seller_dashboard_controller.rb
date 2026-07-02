class SellerDashboardController < ApplicationController
  def index
    # In a real app, you would filter by current seller
    # For this POC, we'll show all rentals
    @rentals = Rental.includes(:product, :renter, :payments).all.order(created_at: :desc)
  end
end
