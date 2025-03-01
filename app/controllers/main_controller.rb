class MainController < ActionController::API
  #skip_before_action :verify_authenticity_token

  # Health check action
  def health_check
    render plain: "API is running"
  end

  # Validate action
  def validate
    unless params[:file].present?
      render json: { error: "Missing file upload" }, status: :bad_request
      return
    end

    file = params[:file].tempfile
    emails = file.readlines.map(&:strip).reject(&:empty?)

    filename = "results_#{SecureRandom.hex(8)}.txt"
    filepath = Rails.root.join("public", filename)

    domain_cache = {}

    File.open(filepath, 'w') do |f|
      emails.each do |user|
        next f.puts "#{user} - Invalid email format" unless user.include?("@")

        domain = extract_domain(user)
        tenant = domain_cache[domain] || fetch_tenant_name(domain)

        domain_cache[domain] = tenant unless tenant.nil?

        if tenant.nil?
          f.puts "#{user} - Failed to retrieve tenant"
        else
          EmailWorker.perform_async(tenant, user, filepath.to_s)
        end
      end
    end

    render json: { message: "Get the results at /download/#{filename}" }
  end

  # Download action
  def download
    filename = params[:filename]
    filename += ".txt" unless filename.end_with?(".txt")

    # Validate filename to prevent directory traversal attacks
    if filename.match?(/\A[a-zA-Z0-9_\-\.]+\z/)
      filepath = Rails.root.join("public", filename)
    else
      render plain: "Invalid filename", status: :bad_request
      return
    end

    if File.exist?(filepath)
      begin
        # Set response headers for file download
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        response.headers['Content-Type'] = 'application/octet-stream'
        response.headers['Cache-Control'] = 'no-cache'

        # Stream the file in chunks
        File.open(filepath, 'rb') do |file|
          while chunk = file.read(1024) # Read in 1 KB chunks
            response.stream.write(chunk)
          end
        end
      ensure
        # Ensure the file is deleted and the stream is closed
        File.delete(filepath) if File.exist?(filepath)
        response.stream.close
      end
    else
      render plain: "File not found", status: :not_found
    end
  end

  private

  def extract_domain(user)
    user.split('@').last
  end

  def fetch_tenant_name(domain)
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
      puts "Erro ao buscar tenant: #{e.message}"
      nil
    end
  end
end
