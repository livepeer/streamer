require_relative 'stream'
require 'faraday'
require 'json'

module Streamer
  class Livepeer
    attr_reader :host
    attr_reader :api_key

    def initialize(host:, api_key:)
      @host = host
      @api_key = api_key
    end

    def base_url
      "https://#{host}"
    end

    def create_stream(name:, profiles: nil)
      body = {
        name: name
      }
      body[:profiles] = profiles unless profiles.nil?

      response = conn.post("/api/stream", body.to_json)

      json = JSON.parse(response.body)
      json["platform"] = @host

      Stream.new(json)
    end

    def delete_stream(stream_id)
      conn.delete("/api/stream/#{stream_id}")
    end

    private

    def conn
      headers ||= {
        "Authorization": "Bearer #{api_key}",
        "Content-Type": 'application/json',
      }

      @conn ||= Faraday::Connection.new(base_url, headers: headers) do |c|
        c.use Faraday::Response::RaiseError
      end
    end
  end
end
