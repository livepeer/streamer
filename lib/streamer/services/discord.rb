require 'json'

module Streamer
  class Discord
    attr_reader :webhook

    def initialize(webhook:)
      @webhook = webhook
    end

    def unexpected_playlist!(cycle, actual, expected)
      message = <<~MSG
        Unexpected Playlist:
        ```
        #{cycle.current_playlist}
        ```
        Try watching stream: #{cycle.bitmovin_url}
      MSG
      send(content: message)
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
