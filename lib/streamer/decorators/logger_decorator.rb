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

      c.before(:booted) do
        info("Booting")
      end

      c.after(:booted) do
        info("Booted")
      end

      c.before(:start_broadcast) do
        info("[#{c.ingest_region}->#{c.playback_region}] starting #{c.duration}s broadcast")
      end

      c.after(:start_broadcast) do
        info("Executed #{c.broadcaster.command} #{c.broadcaster.args.join(" ")}")
        info("Watch: #{c.bitmovin_url}")
        info("Waiting #{c.grace}s before booting monitors")
      end

      c.before(:shutdown) do
        info("Shutting down...")
      end

      c.after(:broadcast_success) do
        info("Broadcast successful")
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
