class AddNameToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :name, :string
  end
end
