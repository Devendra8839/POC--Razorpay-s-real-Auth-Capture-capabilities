class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :seller, null: false, foreign_key: true
      t.integer :per_day_rent
      t.integer :security_deposit

      t.timestamps
    end
  end
end
