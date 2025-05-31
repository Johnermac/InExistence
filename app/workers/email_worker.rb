require 'httpx'

class EmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3  

  
  def perform(email, filepath, redis_key) 
    
    unless email.present?
      Rails.logger.info "\n\n\tEmail not present: #{email}. Skipping."
      decrement_counter(redis_key, filepath) # Ensure counter is decremented even if email is invalid
      return
    end

    unless EmailValidator.valid?(email)
      Rails.logger.info "\n\n\tInvalid email format: #{email}. Skipping."
      decrement_counter(redis_key, filepath) # Ensure counter is decremented even if email is invalid
      return
    end

    puts "\n\n\t => EMAIL: #{email}"

    # Extract and validate domain
    domain = extract_domain(email)   
    puts "\n\t => DOMAIN: #{domain}" 

    # Fetch tenant from cache or API
    tenant = DomainService.fetch_tenant_name(domain)
    if tenant.nil?
      Rails.logger.error "\n\n\t Tenant could not be fetched for domain: #{domain}. Skipping email: #{email}"
      decrement_counter(redis_key, filepath) # Decrement even if we skip the email
      return
    end

    puts "\n\t => TENANT: #{tenant}"

    # Construct verification URL and verify email
    url = construct_url(tenant, email)

    puts "\n\t => URL: #{url}"


    fetch_url(url, filepath, email) if url.present?    

    # Decrement counter in Redis
    decrement_counter(redis_key, filepath)
    
  end


  private

  # Extract domain from email
  def extract_domain(email)
    DomainService.extract_domain(email)
  rescue StandardError => e
    Rails.logger.error "Error extracting domain for #{email}: #{e.message}"
    nil
  end  


  # Construct the email verification URL
  def construct_url(tenant, email)
    user = email.gsub(/\W/, '_') # Sanitize username for the URL
    "https://#{tenant}-my.sharepoint.com/personal/#{user}/_layouts/15/onedrive.aspx"
  rescue StandardError => e
    Rails.logger.error "Error constructing URL for #{email}: #{e.message}"
    nil
  end


  # Verify email and append to file if valid
  def fetch_url(url, filepath, email)
    response = HTTPX.with_headers(
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
    ).get(url)

    if response.status == 200 || response.status == 302
      puts "\n\t => VERIFIED: #{email}"
      append_verified_email(filepath, email)      
    else
      puts "\n\t => NOT VERIFIED: #{email}"
      Rails.logger.info "Email not verified: #{email}, Response Code: #{response.status}"
    end
  rescue HTTPX::Error => e
    Rails.logger.error "HTTPX request failed for #{url}. Error: #{e.message}"
  end



  # Append verified email to results file
  def append_verified_email(filepath, email)
    File.open(filepath, 'a:UTF-8') do |file|
      begin
        file.flock(File::LOCK_EX)
        file.puts(email)
      ensure
        file.flock(File::LOCK_UN)
      end
    end
  rescue StandardError => e
    puts "\n\n\t ERROR WRITING TO FILE"
    Rails.logger.error "Failed to write to file #{filepath}: #{e.message}"
  end


  def decrement_counter(redis_key, filepath)
    begin
      redis = Redis.new # Cria uma nova conexão com Redis
      remaining = redis.decr(redis_key).to_i
  
      if remaining <= 0
        Rails.logger.info "\n\n\t => Email validation completed for: #{redis_key}"
        redis.del(redis_key) # Limpa a chave no Redis
        CleanupWorker.schedule_cleanup(filepath, 30)
      end
    rescue => e
      Rails.logger.error "Error decrementing counter: #{e.message}"
    ensure
      redis.close if redis
    end
  end
end
