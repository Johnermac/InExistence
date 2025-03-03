class CleanupWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(filepath)
    base_path = Rails.root.join("public").to_s
    unless filepath.start_with?(base_path)
      Rails.logger.warn "Invalid file path for deletion: #{filepath}"
      return
    end
  
    File.delete(filepath)
    Rails.logger.info "Successfully deleted file: #{filepath}"
  rescue Errno::ENOENT
    Rails.logger.warn "File not found for deletion: #{filepath}"
  rescue Errno::EACCES
    Rails.logger.error "Permission denied for file deletion: #{filepath}"
  rescue StandardError => e
    Rails.logger.error "Error while trying to delete file: #{filepath}. Error: #{e.message}"
  end
end
