module RazorpayLogging
  extend ActiveSupport::Concern
  
  included do
    after_create :log_razorpay_event
  end
  
  def log_razorpay_event
    # This will be overridden in specific models
  end
  
  def log_api_call(method, endpoint, request_data, response_data, success = true)
    # Ensure this method can be called on the class itself for logging failures
    return unless respond_to?(:id) || self.is_a?(Class)
    log_entry = {
      timestamp: Time.current.iso8601,
      method: method,
      endpoint: endpoint,
      request: request_data,
      response: response_data,
      success: success,
      model: self.class.name,
      record_id: id
    }
    
    Rails.logger.info "[Razorpay API] #{log_entry.to_json}"
    
    # In production, you might want to store this in a database
    # RazorpayApiLog.create(log_entry)
  end
end