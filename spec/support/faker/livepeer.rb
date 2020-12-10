require 'faker'

module Faker
  class Livepeer < Base
    def self.raw_bad_playlist
      <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
      m3u8
    end

    def self.raw_source_only_playlist
      <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
      m3u8
    end

    def self.raw_full_playlist
      <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        2_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1043856,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        3_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=598544,RESOLUTION=640x360,FRAME-RATE=30,CODECS="avc1.4d401e,mp4a.40.2"
        4_1/index.m3u8
      m3u8
    end

    def self.raw_renamed_playlist(seed: 0, renditions: 3)
      playlist = <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
      m3u8

      next_index = seed * renditions + 1

      renditions.times do |s|
        playlist += <<~m3u8
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
          #{next_index}_1/index.m3u8
        m3u8
        next_index += 1
      end

      playlist
    end
  end
end

