require 'streamer/playlist'

module Streamer
  class Stream
    attr_accessor :name
    attr_accessor :profiles
    attr_accessor :id
    attr_accessor :stream_key
    attr_accessor :playback_id
    attr_accessor :platform
    attr_accessor :user_id
    attr_accessor :ingest_region
    attr_accessor :playback_region
    attr_accessor :current_playlist
    attr_accessor :expected_playlist

    def initialize(hash)
      @name = hash["name"]
      @profiles = hash["profiles"]
      @id = hash["id"]
      @stream_key = hash["streamKey"]
      @playback_id = hash["playbackId"]
      @user_id = hash["userId"]
      @platform = hash["platform"]
      @ingest_region = hash["ingest_region"]
      @playback_region = hash["playback_region"]

      @profiles ||= []
    end

    def rtmp_ingest_url
      "rtmp://#{ingest_region}-rtmp.#{platform}/live/#{stream_key}"
    end

    def playback_url
      "https://#{playback_region}-cdn.#{platform}/hls/#{playback_id}/index.m3u8"
    end
    alias :playback :playback_url

    def source
      "https://#{playback_region}-cdn.#{platform}/hls/#{playback_id}/0_1/index.m3u8"
    end

    def renditions
      return [] if current_playlist.nil?
      current_playlist.renditions.map do |x|
        "https://#{playback_region}-cdn.#{platform}/hls/#{playback_id}/#{x}"
      end
    end

    def expected_playlist_size
      @profiles.count + 1
    end

    def current_playlist_size
      @current_playlist.size
    end

    def fetch_playlist!
      @current_playlist = Playlist.new(get_playlist_body)
    end

    def get_playlist_body
      Faraday.get(playback_url).body
    end

    def bitmovin_url
      URI::HTTPS.build(
        host: "bitmovin.com",
        path: "/demos/stream-test",
        query: URI.encode_www_form(
          format: "hls",
          manifest: playback,
        )
      ).to_s
    end
  end
end

