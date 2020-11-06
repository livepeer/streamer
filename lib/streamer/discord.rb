require 'json'

module Streamer
  class Discord
    attr_reader :webhook

    def initialize(webhook:)
      @webhook = webhook
    end

    def send(content)
      response = Faraday.post(webhook) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = content.to_json
      end
      response
    end

  end
end
