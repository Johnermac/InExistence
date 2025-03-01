class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle('requests by ip', limit: 50, period: 60.seconds) do |req|
    req.ip
  end

  self.throttled_response = lambda do |_env|
    [429, { 'Content-Type' => 'application/json' }, [{ error: 'Rate limit exceeded' }.to_json]]
  end
end
