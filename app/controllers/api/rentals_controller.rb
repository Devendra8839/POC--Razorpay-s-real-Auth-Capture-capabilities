class Api::RentalsController < ApplicationController
  before_action :set_rental, only: [:show, :update, :destroy]
  
  # GET /api/rentals
  def index
    @rentals = Rental.all
    render json: @rentals
  end
  
  # GET /api/rentals/1
  def show
    render json: @rental
  end
  
  # POST /api/rentals
  def create
    @rental = Rental.new(rental_params)
    
    if @rental.save
      render json: @rental, status: :created
    else
      render json: @rental.errors, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/rentals/1
  def update
    if @rental.update(rental_params)
      render json: @rental
    else
      render json: @rental.errors, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/rentals/1
  def destroy
    @rental.destroy
    head :no_content
  end
  
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_rental
      @rental = Rental.find(params[:id])
    end
    
    # Only allow a list of trusted parameters through.
    def rental_params
      params.require(:rental).permit(:product_id, :renter_id, :days, :rental_amount, :security_amount, :status)
    end
end
