require 'httparty'

class EmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  # Initialize a persistent cache at the worker class level
  @domain_cache = {}

  class << self
    attr_accessor :domain_cache
  end

  def perform(email, filepath) 

    return unless email.present?    
    
    return unless EmailValidator.valid?(email)
    puts "\n\n => email => #{email}"

    # Extract and validate domain
    domain = extract_domain(email)   
    puts "\n => DOMAIN => #{domain}" 

    # Fetch tenant from the cache or fetch it remotely
    tenant = self.class.domain_cache[domain] || DomainService.fetch_tenant_name(domain)
    if tenant
      # Cache the tenant for future use
      self.class.domain_cache[domain] = tenant
      puts "\n => CACHE: #{self.class.domain_cache}"

      puts "\n => TENANT => #{tenant}\n" 

      # Construct verification URL and verify email
      url = construct_url(tenant, email)
      fetch_url(url, filepath, email) if url.present?
    else
      puts "\n => Tenant not found for domain: #{domain}"
    end    
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
    response = HTTParty.get(url, headers: {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
    })

    if response.code == 200 || response.code == 302
      append_verified_email(filepath, email)
    else
      Rails.logger.info "Email not verified: #{email}, Response Code: #{response.code}"
    end
  rescue HTTParty::Error, StandardError => e
    Rails.logger.error "HTTP request failed for #{url}. Error: #{e.message}"
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
    Rails.logger.error "Failed to write to file #{filepath}: #{e.message}"
  end
end
