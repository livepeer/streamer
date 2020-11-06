module Streamer
  class Stream
    attr_accessor :name
    attr_accessor :renditions
    attr_accessor :id
    attr_accessor :stream_key
    attr_accessor :playback_id
    attr_accessor :platform
    attr_accessor :user_id

    def initialize(hash)
      @name = hash["name"]
      @renditions = hash["renditions"]
      @id = hash["id"]
      @stream_key = hash["streamKey"]
      @playback_id = hash["playbackId"]
      @user_id = hash["userId"]
      @platform = hash["platform"]
    end

    def rtmp_ingest_url(region)
      "rtmp://#{region}-rtmp.#{platform}/live/#{stream_key}"
    end

    def playback_url(region)
      "https://#{region}-cdn.#{platform}/hls/#{playback_id}/index.m3u8"
    end
  end
end

