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
  
    # Chunk the emails into batches of 100 and enqueue workers
    emails.each_slice(100).each do |batch|
      batch.each do |email|
        EmailWorker.perform_async(email, filepath.to_s)
      end
    end
  
    render json: { 
      message: "http://172.29.243.192:3000/download/#{filename}" 
    }
  end
  

  # Download action
  def download
    filename = params[:filename]
    filename += ".txt" unless filename.end_with?(".txt") # Adjusted for JSON files
  
    # Validate filename against the stricter regex
    unless filename.match?(/\Aresults_[a-f0-9]{16}\.txt\z/)
      render plain: "Invalid filename", status: :bad_request
      return
    end

    filepath = Rails.root.join("public", filename)
  
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
        CleanupWorker.perform_async(filepath.to_s) if File.exist?(filepath)
        response.stream.close
      end
    else
      render plain: "File not found", status: :not_found
    end
  end  
end

