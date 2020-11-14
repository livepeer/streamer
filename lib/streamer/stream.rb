module Streamer
  class Stream
    attr_accessor :name
    attr_accessor :renditions
    attr_accessor :id
    attr_accessor :stream_key
    attr_accessor :playback_id
    attr_accessor :platform
    attr_accessor :user_id
    attr_accessor :ingest_region
    attr_accessor :playback_region

    def initialize(hash)
      @name = hash["name"]
      @renditions = hash["renditions"]
      @id = hash["id"]
      @stream_key = hash["streamKey"]
      @playback_id = hash["playbackId"]
      @user_id = hash["userId"]
      @platform = hash["platform"]
      @ingest_region = hash["ingest_region"]
      @playback_region = hash["playback_region"]
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

    def fetch_playlist_size
      fetch_playlist.scan(/#EXT-X-STREAM-INF/).length
    end

    def fetch_playlist
      Faraday.get(playback_url).body
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

