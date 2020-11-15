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
        info("Watch here: #{c.bitmovin_url}")
        info("Waiting #{c.grace}s before considering the stream booted")
      end

      c.before(:shutdown) do
        info("Shutting down...")
      end

      c.after(:start_monitoring_playlist) do
        info("Started playlist monitor")
      end

      c.after(:broadcast_success) do
        info("Broadcast successful")
      end

      c.after(:unexpected_playlist) do
        info("Unexpected Playlist:\n#{c.current_playlist}")
      end

      c.after(:broadcast_terminated) do
        info("Broadcast terminated")
      end

      c.before(:broadcast_failed) do
        info("Broadcast failed")
      end

      c.after(:broadcast_exited) do
        info("Broadcast exited")
      end

      c.before(:interrupt) do
        info("Trapped interrupt signal")
      end

      c.before(:stop_monitoring_playlist) do
        info("Stopping playlist monitor")
      end

      c.before(:stop_monitoring_source) do
        info("Stopping source monitor")
      end

      c.before(:stop_broadcast) do
        info("Stopping broadcast")
      end

      c.before(:destroy_stream) do
        info("Destroying stream at #{c.livepeer.base_url}")
      end

      c.after(:shutdown) do
        info("Done")
        info("---")
      end
    end
  end

end
