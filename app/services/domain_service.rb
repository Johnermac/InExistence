require 'httparty'

class DomainService
  include HTTParty
  base_uri 'https://aadinternals.azurewebsites.net'

  def self.extract_domain(user)
    user.split('@').last
  end

  def self.fetch_tenant_name(domain)
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

      data = JSON.parse(body)
      data["tenantName"]&.split('.onmicrosoft.com')&.first
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error for domain #{domain}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Error fetching tenant for domain #{domain}: #{e.message}"
      nil
    end
  end
end
