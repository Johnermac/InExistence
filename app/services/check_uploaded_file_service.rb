class CheckUploadedFileService
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_EXTENSIONS = [".txt"].freeze
  ALLOWED_MIME_TYPES = ["text/plain"].freeze

  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
  end

  def validate
    # Execute each validation method in sequence, stopping at the first failure
    result = validate_content_type
    return result unless result[:valid]    

    result = validate_extension
    return result unless result[:valid]

    result = validate_mime_type
    return result unless result[:valid]

    result = validate_file_size
    return result unless result[:valid]

    result = validate_content
    return result unless result[:valid]

    { valid: true }
  end

  private

  def validate_content_type
    mime_type = Marcel::MimeType.for(@uploaded_file.tempfile, name: @uploaded_file.original_filename)
    unless ALLOWED_MIME_TYPES.include?(mime_type)
      puts "\n => VALIDATION 0 FAILED: #{@uploaded_file.content_type}"
      return { valid: false, error: "Invalid file content type. Detected type: #{mime_type}. Only plain text files are allowed." }
    end
    { valid: true }
  rescue StandardError => e
    Rails.logger.error "Error detecting MIME type: #{e.message}"
    { valid: false, error: "Error detecting file content type." }
  end

  def validate_extension
    unless ALLOWED_EXTENSIONS.include?(File.extname(@uploaded_file.original_filename).downcase)
      puts "\n => VALIDATION 1 FAILED: #{File.extname(@uploaded_file.original_filename)}"
      return { valid: false, error: "Invalid file extension. Only #{ALLOWED_EXTENSIONS.join(', ')} files are allowed." }
    end
    { valid: true }
  end

  def validate_mime_type
    unless ALLOWED_MIME_TYPES.include?(@uploaded_file.content_type)
      puts "\n => VALIDATION 2 FAILED: #{@uploaded_file.content_type}"
      return { valid: false, error: "Invalid file MIME type. Only #{ALLOWED_MIME_TYPES.join(', ')} are allowed." }
    end
    { valid: true }
  end

  def validate_file_size
    if @uploaded_file.size > MAX_FILE_SIZE
      puts "\n => VALIDATION 3 FAILED: #{@uploaded_file.size} bytes"
      return { valid: false, error: "File exceeds the maximum allowed size of #{MAX_FILE_SIZE / 1.megabyte} MB." }
    end
    { valid: true }
  end

  def validate_content
    file_content = File.read(@uploaded_file.tempfile)
    if file_content.match(/<\?php|<script>/i)
      puts "\n => VALIDATION 4 FAILED: Potentially malicious content detected"
      return { valid: false, error: "File contains potentially malicious content." }
    end
    { valid: true }
  rescue StandardError => e
    Rails.logger.error "Error reading file content: #{e.message}"
    { valid: false, error: "Error validating file content." }
  end
end
