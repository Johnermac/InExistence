class CleanupWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(filepath)
    base_path = Rails.root.join("public").to_s
    unless filepath.start_with?(base_path)
      Rails.logger.warn "\n\n\tInvalid file path for deletion: #{filepath}"
      return
    end
  
    File.delete(filepath)
    Rails.logger.info "\n\n\t => Successfully deleted file: #{filepath}"
  rescue Errno::ENOENT
    Rails.logger.warn "\n\n\tFile not found for deletion: #{filepath}"
  rescue Errno::EACCES
    Rails.logger.error "\n\n\tPermission denied for file deletion: #{filepath}"
  rescue StandardError => e
    Rails.logger.error "\n\n\tError while trying to delete file: #{filepath}. Error: #{e.message}"
  end

  def self.schedule_cleanup(filepath, delay_in_seconds)
    Rails.logger.info "\n\n => Deletion will happen in #{delay_in_seconds} Seconds: #{filepath}"
    perform_in(delay_in_seconds, filepath)    
  end
end
