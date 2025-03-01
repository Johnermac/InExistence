require 'httparty'

class EmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(tenant, user, filepath)
    user_ = user.gsub(/\W/, '_')  
    url = "https://#{tenant}-my.sharepoint.com/personal/#{user_}/_layouts/15/onedrive.aspx"

    puts "Fetching URL: #{url} for user: #{user} in tenant: #{tenant}"

    # Perform the HTTP request using HTTParty
    response = HTTParty.get(url, headers: {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
    })

    # Handle the response
    status = case response.code
             when 302,200
               { "user" => user, "status" => "OK" }
             when 404
               { "user" => user, "status" => "NOT OK" }
             else
               { "user" => user, "status" => "Failed: #{response.code}" }
             end

    # Log the status into the file
    File.open(filepath, 'a:UTF-8') { |file| file.puts(status.to_json) }
  end
end
