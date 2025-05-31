require 'httpx'
require 'nokogiri'

class DomainService
  def self.extract_domain(user)
    user.split('@').last
  end


  def self.fetch_tenant_name(domain)
    return nil if domain.nil? || domain.strip.empty?

    Rails.cache.fetch("tenant_name:#{domain}", expires_in: 2.hours) do
      Rails.logger.info "Cache miss for domain: #{domain}. Fetching from API..."
      puts "\n\t => Cache miss for domain: #{domain}. Fetching from API..."

      response = api_fetch_tenant_name(domain)
      if response
        tenant_name = response["tenantName"]&.split('.onmicrosoft.com')&.first
        if tenant_name.present?
          puts "\n\t => Fetched and caching tenant for domain: #{domain}: #{tenant_name}"
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


  def self.api_fetch_tenant_name(domain)
    return nil if domain.nil? || domain.strip.empty?

    url = 'https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc'

    headers = {
      'Content-Type' => 'text/xml; charset=utf-8',
      'SOAPAction' => 'http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation',
      'User-Agent' => 'AutodiscoverClient',
      'Accept-Encoding' => 'identity'
    }

    soap_body = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:exm="http://schemas.microsoft.com/exchange/services/2006/messages"
                    xmlns:ext="http://schemas.microsoft.com/exchange/services/2006/types"
                    xmlns:a="http://www.w3.org/2005/08/addressing"
                    xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Header>
              <a:Action soap:mustUnderstand="1">http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation</a:Action>
              <a:To soap:mustUnderstand="1">#{url}</a:To>
              <a:ReplyTo>
                  <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
              </a:ReplyTo>
          </soap:Header>
          <soap:Body>
              <GetFederationInformationRequestMessage xmlns="http://schemas.microsoft.com/exchange/2010/Autodiscover">
                  <Request>
                      <Domain>#{domain}</Domain>
                  </Request>
              </GetFederationInformationRequestMessage>
          </soap:Body>
      </soap:Envelope>
    XML

    begin
      puts "\n\t => Fetching tenant for domain: #{domain} (SOAP autodiscover)"
      response = HTTPX.post(url, body: soap_body, headers: headers)

      if response.status != 200
        Rails.logger.error "SOAP Error: HTTP #{response.status} - #{response.reason} for domain #{domain}"
        return nil
      end

      doc = Nokogiri::XML(response.to_s)
      doc.remove_namespaces!

      domains = doc.xpath("//Domain").map(&:text).uniq
      tenant_domain = domains.find { |d| d =~ /\A([a-z0-9\-]+)(\.mail)?\.onmicrosoft\.com\z/i }

      if tenant_domain
        tenant_name = tenant_domain.split('.').first
        puts "\n\t => Tenant identified: #{tenant_name} from domain #{tenant_domain}"
        return { "tenantName" => tenant_name }
      else
        Rails.logger.info "No tenant domain found for #{domain}. Got: #{domains.inspect}"
        nil
      end
    rescue => e
      Rails.logger.error "Error during SOAP fetch for domain #{domain}: #{e.message}"
      nil
    end
  end
end
