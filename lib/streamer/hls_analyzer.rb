module Streamer
  class HlsAnalyzer
    attr_reader :conn
    attr_reader :host
    attr_reader :api_key

    def initialize(host:, api_key:)
      @host = host
      @api_key = api_key

      @conn = Faraday.new(
        headers: {
          "Content-Type": 'application/json',
        },
        url: base_url,
      )

      # @conn.use Faraday::Response::RaiseError
    end

    def base_url
      "https://#{host}"
    end

    def add(m3u8)
      response = conn.get("/api/add") do |req|
        req.params["m3u8"] = source_stream_for(m3u8)
        req.params["apikey"] = api_key
      end

      JSON.parse(response.body)
    end

    def remove(m3u8)
      response = conn.get("/api/remove") do |req|
        req.params["m3u8"] = source_stream_for(m3u8)
        req.params["apikey"] = api_key
      end
      JSON.parse(response.body)
    end

    def status(m3u8)
      response = conn.get("/api/status") do |req|
        req.params["m3u8"] = source_stream_for(m3u8)
        req.params["apikey"] = api_key
      end
      JSON.parse(response.body)
    end

    def source_stream_for(url)
      url.gsub('/index.m3u8', '/0_1/index.m3u8')
    end

  end
end
