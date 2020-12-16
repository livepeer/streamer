module Streamer
  class PlaylistMonitorReporter
    attr_reader :discord
    attr_reader :pagerduty
    attr_reader :logger
    attr_reader :monitor
    attr_reader :cycle

    def initialize(discord:, pagerduty:, logger:, monitor:)
      @discord = discord
      @pagerduty = pagerduty
      @logger = logger
      @monitor = monitor
      @cycle = nil
    end

    def decorate(c)
      @cycle = c

      monitor.on(:alert_started) do
        message = <<~MSG.chomp
          Cycle (#{cycle.ingest_region}->#{cycle.playback_region}) has experienced a bad playlist.
        MSG

        discord.post(content: message)
        logger.warn(message)
      end

      monitor.on(:alert_stopped) do
        message = <<~MSG.chomp
          Cycle (#{cycle.ingest_region}->#{cycle.playback_region}) experienced bad playlists (#{monitor.errors.count}x) for #{monitor.pretty_duration}. Normal playlists have resumed.
        MSG

        logger.warn(message)
        discord.post(content: message)
      end

      monitor.on(:alarm_started) do
        message = <<~MSG.chomp
          Cycle (#{cycle.ingest_region}->#{cycle.playback_region}) has been experiencing bad playlists (#{monitor.errors.count}x) for over #{monitor.pretty_duration}.
        MSG

        logger.warn(message)
        discord.post(content: message)
        pagerduty.trigger("playlist-alarm", {
          summary: message,
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
            alert_started_at: monitor.alert_started_at,
            errors: monitor.errors.count,
          }
        })
      end

      monitor.on(:bad_playlist) { |m, e| logger.warn(e) }

      monitor.on(:sampled) do |m, e|
        if e == :rename
          message = <<~MSG.chomp
            Cycle (#{cycle.ingest_region}->#{cycle.playback_region}) saw rename.
          MSG

          logger.warn(message)
          discord.post(content: message)
        end
      end

      monitor.on(:shutdown) do
        if monitor.alerting? or monitor.alarming?
          message = <<~MSG.chomp
            Cycle (#{cycle.ingest_region}->#{cycle.playback_region}) experienced bad playlists (#{monitor.errors.count}x) for #{monitor.pretty_duration} before shutdown.
          MSG

          logger.warn(message)
          discord.post(content: message)
        end
      end

      c.after(:start_monitoring_playlist) do
        logger.info("Started playlist monitor")
      end

      c.before(:stop_monitoring_playlist) do
        logger.info("Stopping playlist monitor")
      end

      c.after(:unexpected_playlist) do
        logger.info("Unexpected Playlist:\n#{c.current_playlist.raw}")
      end
    end

  end
end
