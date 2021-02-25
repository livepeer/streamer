require 'active_support/core_ext'

module Streamer

  # Samples a playlist and classifies the result
  #
  # It currently will detect the following events:
  #   - normal
  #   - source_only, a playlist without renditions
  #   - renamed,  a playlist with renditions at new urls
  #   - null, an empty playlist
  #   - stream_error, an playlist with error contents
  #   - connection_failed_error, couldn't fetch the playlist
  #   - timeout_error, playlist request took too long
  #   - client_error, catch all for any client http error
  #   - server_error, catch all for any server http error
  #
  class PlaylistSampler
    attr_reader :stream

    def initialize(stream)
      @stream = stream
      @last_normal_playlist = nil
    end

    def sample
      stream.fetch_playlist!.tap do |sample|
        if sample.source_only?
          record(:source_only)
        elsif sample.nil?
          record(:null)
        elsif sample.error?
          record(:stream_error)
        else
          if sample.renamed?(@last_normal_playlist)
            record(:rename)
          else
            record(:normal)
          end

          @last_normal_playlist = sample
        end

      rescue Faraday::ConnectionFailed => e
        record(:conection_failed_error)
      rescue Faraday::TimeoutError => e
        record(:timeout_error)
      rescue Faraday::ClientError => e
        record(:client_error)
      rescue Faraday::ServerError => e
        record(:server_error)
      end

      @last_event
    end

    def record(event)
      @last_event = event
    end
  end

end

