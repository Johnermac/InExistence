# app/services/domain_service.rb
class DomainService
  def self.extract_domain(user)
    user.split('@').last
  end

  def self.fetch_tenant_name(domain)
    url = URI("https://aadinternals.azurewebsites.net/api/tenantinfo?domainName=#{URI.encode_www_form_component(domain)}")

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(url)
      request['Host'] = "aadinternals.azurewebsites.net"
      request['User-Agent'] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0"
      request['Accept'] = "application/json, text/javascript, */*; q=0.01"
      request['Origin'] = "https://aadinternals.com"
      request['Referer'] = "https://aadinternals.com/"
      request['Content-Length'] = "6"
      request.body = "\x0d\x0a\x0d\x0a\x0d\x0a"

      response = http.request(request)

      if response.code.to_i != 200
        puts "Erro na API: HTTP #{response.code} - #{response.message}"
        return nil
      end

      body = response.body.strip
      return nil if body.empty?

      data = JSON.parse(body) rescue nil
      return nil if data.nil?

      if data["tenantName"] && data["tenantName"].include?(".onmicrosoft.com")
        data["tenantName"].split('.onmicrosoft.com').first
      else
        nil
      end

    rescue StandardError => e
      Rails.logger.error "Error fetching tenant for domain #{domain}: #{e.message}"
      nil
    end
  end
end
