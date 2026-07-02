class AddRentalIdToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :rental_id, :integer
  end
end
