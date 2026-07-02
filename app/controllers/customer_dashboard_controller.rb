class CustomerDashboardController < ApplicationController
  def index
    # In a real app, you would filter by current user
    # For this POC, we'll show all rentals
    @rentals = Rental.includes(:payments, product: :seller).all.order(created_at: :desc)
  end
end
