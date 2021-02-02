module Streamer
  class PageOnExcessiveRename
    attr_reader :pagerduty
    attr_reader :logger
    attr_reader :discord
    attr_reader :max_renames
    attr_reader :rename_count
    attr_reader :cycle

    def initialize(
      pagerduty:,
      discord:,
      logger:,
      max_renames: 5
    )
      @pagerduty = pagerduty
      @logger = logger
      @discord = discord
      @max_renames = max_renames || 5
      @rename_count = 0
      @paged = false
    end

    def decorate(cycle)
      @cycle = cycle

      cycle.after(:sampled_playlist_rename) { record_rename }
    end

    def record_rename
      @rename_count += 1
      page! if rename_count >= max_renames and !paged?
    end

    def page!
      message = <<~MSG.chomp
        [#{cycle.ingest_region}->#{cycle.playback_region}] has experienced (#{rename_count}) renamed playlists
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
          rename_count: rename_count,
        }
      })
      @paged = true
    end

    def paged?
      @paged
    end

    def reset
      @paged = false
      @renames = 0
    end
  end
end
