class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.string :payment_id
      t.string :order_id
      t.string :authorization_id
      t.string :capture_id
      t.string :refund_id
      t.string :status
      t.integer :amount
      t.string :payment_type
      t.string :payment_method

      t.timestamps
    end
  end
end
