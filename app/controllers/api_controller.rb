class ApiController < ActionController::API
  include ActionController::RequestForgeryProtection

  # Skip CSRF verification for specific actions (if needed)
  skip_before_action :verify_authenticity_token
end
