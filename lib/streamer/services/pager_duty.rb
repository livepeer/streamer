require 'pagerduty'

module Streamer
  class PagerDuty
    attr_reader :integration_key
    attr_reader :client
    attr_reader :component

    def initialize(integration_key:,component:)
      @component = component
      @client = ::Pagerduty.build(
        integration_key: integration_key,
        api_version: 2
      )
    end

    delegate :trigger, to: :client

    def trigger_unexpected_playlist(cycle)
      @client.trigger(
        summary: "Unexpected Playlist Detected (#{component})",
        source: cycle.ingest,
        severity: "error",
        timestamp: Time.now,
        component: cycle.session_name,
        links: [
          {
            href: cycle.bitmovin_url,
            text: "Playback (bitmovin)",
          },
        ],
        custom_details: {
          ingest: cycle.ingest,
          playback: cycle.playback,
          actual_size: cycle.current_playlist_size,
          expected_size: cycle.expected_playlist_size,
          profiles: cycle.profiles,
          playlist: cycle.current_playlist,
        }
      )
    end

  end
end

