Rental.destroy_all
Product.destroy_all
Seller.destroy_all
User.destroy_all

user = User.create!(name: "Test User", email: "test@example.com")
seller = Seller.create!(name: "Test Seller")
product = Product.create!(seller: seller, per_day_rent: 1000, security_deposit: 5000)

rental = Rental.create!(
  product: product, 
  renter: user, 
  days: 3, 
  rental_amount: 3000, 
  security_amount: 5000, 
  status: 'requested'
)

puts "Successfully seeded database with user, seller, product, and a requested rental!"
