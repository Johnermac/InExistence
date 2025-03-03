require 'httparty'

class DomainService
  include HTTParty
  base_uri 'https://aadinternals.azurewebsites.net'

  def self.extract_domain(user)
    user.split('@').last
  end

  def self.fetch_tenant_name(domain)
    return nil if domain.nil? || domain.strip.empty?
  
    cached_value = Rails.cache.read("tenant_name:#{domain}")
    if cached_value
      puts "\n => Cache hit for domain: #{domain} - #{cached_value}"
      return cached_value
    end
  
    Rails.logger.info "Cache miss for domain: #{domain}. Fetching from API..."
    Rails.cache.fetch("tenant_name:#{domain}", expires_in: 2.hours) do
      response = api_fetch_tenant_name(domain)
      if response
        tenant_name = response["tenantName"]&.split('.onmicrosoft.com')&.first
        if tenant_name.present?
          puts "\n => Fetched and caching tenant for domain: #{domain}: #{tenant_name}"
          tenant_name
        else
          Rails.logger.error "Invalid tenant data for domain: #{domain}"
          nil
        end
      else
        nil
      end
    end
  end
  

  # Simulated API fetch method
  def self.api_fetch_tenant_name(domain)
    puts "\nFetching tenant for domain: #{domain} (API call)"

    # Return nil for invalid or empty domains
    return nil if domain.nil? || domain.strip.empty?

    # Construct the URL with query parameter
    endpoint = "/api/tenantinfo"
    query = { domainName: domain }

    # Headers for the request
    headers = {
      'Host' => "aadinternals.azurewebsites.net",
      'User-Agent' => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0",
      'Accept' => "application/json, text/javascript, */*; q=0.01",
      'Origin' => "https://aadinternals.com",
      'Referer' => "https://aadinternals.com/"
    }

    # Perform the GET request using HTTParty
    begin
      response = get(endpoint, query: query, headers: headers)

      if response.code != 200
        Rails.logger.error "API Error: HTTP #{response.code} - #{response.message} for domain #{domain}"
        return nil
      end

      body = response.body.strip
      return nil if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error for domain #{domain}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Error fetching tenant for domain #{domain}: #{e.message}"
      nil
    end
  end
end
