class MainController < ActionController::API
  #skip_before_action :verify_authenticity_token

  require 'email_validator' 
  require 'json'
  
  # Health check action
  def health_check
    render plain: "API is running"
  end  


  # Validate action
  def validate
    unless params[:file].present?
      render json: { error: "Missing file upload" }, status: :bad_request
      return
    end
  
    file = params[:file].tempfile
    emails = file.readlines.map(&:strip).reject(&:empty?)
  
    # Generate a .txt file for storing verified emails
    filename = "results_#{SecureRandom.hex(8)}.txt"
    filepath = Rails.root.join("public", filename)
  
    domain_cache = {}
  
    emails.each do |user|
      begin
        # Validate email format
        next unless EmailValidator.valid?(user)
  
        # Extract and validate domain
        domain = DomainService.extract_domain(user)
  
        # Fetch tenant
        tenant = domain_cache[domain] || DomainService.fetch_tenant_name(domain)
        next if tenant.nil?
  
        # Cache the domain and trigger the EmailWorker
        domain_cache[domain] = tenant
        EmailWorker.perform_async(tenant, user, filepath.to_s)
      rescue StandardError => e
        Rails.logger.error "Error processing #{user}: #{e.message}"
      end
    end
  
    render json: { message: "Verified emails will be saved at http://127.0.0.1:3000/download/#{filename}" }
  end  
   

  # Download action
  def download
    filename = params[:filename]
    filename += ".txt" unless filename.end_with?(".txt") # Adjusted for JSON files
  
    # Validate filename to prevent directory traversal attacks
    if filename.match?(/\A[a-zA-Z0-9_\-\.]+\z/)
      filepath = Rails.root.join("public", filename)
    else
      render plain: "Invalid filename", status: :bad_request
      return
    end
  
    if File.exist?(filepath)
      begin
        # Set response headers for file download
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        response.headers['Content-Type'] = 'application/json' # JSON content type
        response.headers['Cache-Control'] = 'no-cache'
  
        # Stream the file in chunks
        File.open(filepath, 'rb') do |file|
          while chunk = file.read(1024) # Read in 1 KB chunks
            response.stream.write(chunk)
          end
        end
      ensure
        # Ensure the file is deleted and the stream is closed
        File.delete(filepath) if File.exist?(filepath)
        response.stream.close
      end
    else
      render plain: "File not found", status: :not_found
    end
  end
  
    
end

