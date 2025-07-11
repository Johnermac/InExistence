class MainController < ActionController::Base
  skip_before_action :verify_authenticity_token

  require 'email_validator' 
  require 'json'
  
  
  # Health check action
  def index
    render :index
  end    


  # Validate action
  def validate
    
    unless params[:file].present?
      render json: { error: "No file uploaded." }, status: :bad_request
      return
    end

    uploaded_file = params[:file]
    validation_result = CheckUploadedFileService.new(uploaded_file).validate

    unless validation_result[:valid]
      render json: { error: validation_result[:error] }, status: :unprocessable_entity
      return
    end
  
    file = params[:file].tempfile
    emails = file.readlines.map(&:strip).reject(&:empty?)

    # Generate a .txt file for storing verified emails
    filename = "results_#{SecureRandom.hex(8)}.txt"
    filepath = Rails.root.join("public", filename)
  
    # Ensure the 'public' directory exists
    FileUtils.mkdir_p(Rails.root.join("public")) unless Dir.exist?(Rails.root.join("public"))

    # Store the total count in Redis
    redis_key = "email_validation:#{filename}"
    Sidekiq.redis { |conn| conn.set(redis_key, emails.size) }
  
    # Chunk the emails into batches of 100 and enqueue workers
    emails.each_slice(100).each do |batch|
      batch.each do |email|
        EmailWorker.perform_async(email, filepath.to_s, redis_key)        
      end
    end

    # Wait for all validation
    Sidekiq.redis do |conn|      
      until conn.get(redis_key).to_i == 0
        sleep(1) 
      end
    end
  
    render json: { 
      message: "http://127.0.0.1:3000/download/#{filename}" 
    }
  end
  

  # Download action
  def download
    filename = params[:filename]
    filename += ".txt" unless filename.end_with?(".txt")

    unless filename.match?(/\Aresults_[a-f0-9]{16}\.txt\z/)
      render plain: "Invalid filename", status: :bad_request
      return
    end

    filepath = Rails.root.join("public", filename)

    if File.exist?(filepath)
      send_file filepath, filename: filename, type: "text/plain", disposition: "attachment"      
      CleanupWorker.perform_in(300.seconds, filepath.to_s)
    else
      render plain: "File not found", status: :not_found
    end
  end
end

