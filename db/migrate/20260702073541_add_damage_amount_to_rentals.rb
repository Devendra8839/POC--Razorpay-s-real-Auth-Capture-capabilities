class AddDamageAmountToRentals < ActiveRecord::Migration[8.0]
  def change
    add_column :rentals, :damage_amount, :integer
  end
end
