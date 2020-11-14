module Streamer
  class LoggerDecorator
    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def info(message)
      logger.info(message)
    end

    def decorate(cycle)
      c = cycle

      c.before(:init) do
        info("Starting cycle")
      end

      c.before(:create_stream) do
        info("Creating stream at #{c.livepeer.base_url}")
      end

      c.after(:create_stream) do
        info("Created stream. id='#{c.stream.id}' key='#{c.stream.stream_key}' playback='#{c.stream.playback}'")
      end

      c.before(:boot) do
        info("Waiting #{grace}s before adding hlsanalyzer monitor")
      end

      c.after(:boot) do
        info("Booted")
      end

      c.before(:start_broadcast) do
        info("Starting #{c.duration}s broadcast to #{c.ingest}")
      end

      c.after(:start_broadcast) do
        info("Executed #{c.broadcaster.command} #{c.broadcaster.args.join(" ")}")
        info("Waiting #{c.grace}s before considering the stream booted")
      end

      c.after(:done) do
        info "FFMPEG completed successfully"
      end

      c.after(:broadcast_terminated) do
        info "FFMPEG terminated by signal successfully"
      end

      c.after(:broadcast_failed) do
        info "FFMPEG exited non-zero. Notifying watchers"
      end

      c.before(:start_monitoring_source) do
        info("Adding monitor at #{c.analyzer.host}")
      end

      c.after(:start_monitoring_source) do
        info("Added monitor at #{c.analyzer.host}")
      end

      c.before(:shutdown) do
        info("Shutting down")
      end

      c.before(:check_playlist) do
        info("Checking playlist size is #{c.expected_playlist_size}")
      end

      c.after(:check_playlist) do
        info("Expected playlist size of #{c.expected_playlist_size}. Got #{c.current_playlist_size}.")
      end

      c.after(:broadcast_success) do
        info("Broadcast successful")
      end

      c.after(:broadcast_terminated) do
        info("Broadcast terminated")
      end

      c.after(:broadcast_failed) do
        info("Broadcast failed")
      end

      c.after(:broadcast_exited) do
        info("Broadcast exited")
      end

      c.before(:interrupt) do
        info("Trapped interrupt signal")
      end

      events = %i[
        stop_monitoring_playlist
        stop_monitoring_source
        stop_broadcast
        destroy_stream
      ].each do |e|
        c.before(e) do
          info(e.to_s.gsub("_", " ").capitalize)
        end
      end

      c.after(:shutdown) do
        info("Done")
        info("---")
      end
    end
  end

end
