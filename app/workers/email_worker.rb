require 'httparty'

class EmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(tenant, user, filepath)
    url = construct_url(tenant, user)
    response = fetch_url(url, filepath, user)
  end
    

  private
  
  def construct_url(tenant, user)
    user_ = user.gsub(/\W/, '_') # Sanitize username for SharePoint URL
    url = "https://#{tenant}-my.sharepoint.com/personal/#{user_}/_layouts/15/onedrive.aspx"
    puts "\nVerifying email: #{user} at URL: #{url}"
    url
  end
  

  def fetch_url(url, filepath, user)
    # Make HTTP request
    response = HTTParty.get(url, headers: {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
    })

    # Append to file only if the email is verified
    if response.code == 200 || response.code == 302
      append_verified_email(filepath, user)
    else
      Rails.logger.info "Email not verified: #{user}, Response Code: #{response.code}"
    end
  end


  def append_verified_email(filepath, email)
    # Write the verified email to the file
    File.open(filepath, 'a:UTF-8') do |file|
      file.puts(email)
    end
  rescue StandardError => e
    Rails.logger.error "Failed to write to file #{filepath}: #{e.message}"
  end
end
