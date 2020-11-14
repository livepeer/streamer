require 'json'

module Streamer
  class Discord
    attr_reader :webhook

    def initialize(webhook:)
      @webhook = webhook
    end

    def playlist_too_small!(cycle, actual, expected)
      send(content: "Playlist Too Small. Actual: #{actual}. Expected: #{expected}. Is transcoding working?!")
    end

    def send(content)
      return false if webhook.empty?

      response = Faraday.post(webhook) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = content.to_json
      end
      response
    end

  end
end
