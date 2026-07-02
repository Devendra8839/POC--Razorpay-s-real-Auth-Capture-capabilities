class AddOrderIdToRentals < ActiveRecord::Migration[8.0]
  def change
    add_column :rentals, :order_id, :string
    add_column :rentals, :security_order_id, :string
  end
end
