Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resources :rentals
    resources :payments
    
    # Razorpay webhook endpoint
    post '/razorpay/webhook', to: 'razorpay#webhook'
    
    # Payment processing endpoints
    post '/payments/create_order', to: 'payments#create_order'
    post '/payments/capture_payment', to: 'payments#capture_payment'
    post '/payments/authorize_security', to: 'payments#authorize_security'
    post '/payments/capture_authorization', to: 'payments#capture_authorization'
    post '/payments/sync_security_authorization', to: 'payments#sync_security_authorization'
    post '/payments/release_authorization', to: 'payments#release_authorization'
    
    # Rental lifecycle management
    post '/rentals/:rental_id/transition', to: 'rental_lifecycle#transition'
    post '/rentals/:rental_id/admin_capture_damage', to: 'rental_lifecycle#admin_capture_damage'
    get '/rentals/:rental_id/refund_status', to: 'rental_lifecycle#refund_status'
  end

  # Defines the root path route ("/")
  root "seller_dashboard#index"
  
  get '/seller', to: 'seller_dashboard#index'
  get '/customer', to: 'customer_dashboard#index'
  get '/admin', to: 'admin#index'
  post '/admin/create_test_rental', to: 'admin#create_test_rental'
  post '/admin/clear_test_data', to: 'admin#clear_test_data'
end
