class CreateRentals < ActiveRecord::Migration[8.0]
  def change
    create_table :rentals do |t|
      t.references :product, null: false, foreign_key: true
      t.references :renter, null: false, foreign_key: true
      t.integer :days
      t.integer :rental_amount
      t.integer :security_amount
      t.string :status

      t.timestamps
    end
  end
end
