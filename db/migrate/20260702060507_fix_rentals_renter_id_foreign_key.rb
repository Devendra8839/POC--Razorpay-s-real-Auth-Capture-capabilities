class FixRentalsRenterIdForeignKey < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :rentals, :renters if foreign_key_exists?(:rentals, :renters)
    add_foreign_key :rentals, :users, column: :renter_id
  end
end
