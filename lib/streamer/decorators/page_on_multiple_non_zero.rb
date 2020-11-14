module Streamer
  class PageOnUnexpectedPlaylist
    attr_reader :pagerduty
    attr_reader :logger
    attr_reader :failures

    def initialize(pagerduty: pagerduty, logger: logger, max_failures: 3)
      @pagerduty = pagerduty
      @logger = logger
      @failures = 0
    end

    def decorate(cycle)
      cycle.after(:broadcast_failed) do
        @failures += 1
        logger.info("Broadcast has failed #{failures} times in a row")

        if failures > max_failures
          logger.info("Max failures exceeded. Paging")

          pagerduty.trigger(
            summary: "Broadcast Failed more than #{max_failures} in a row (#{component})",
            source: cycle.ingest,
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
              actual_size: cycle.current_playlist_size,
              expected_size: cycle.expected_playlist_size,
              profiles: cycle.profiles,
              playlist: cycle.current_playlist,
            }
          )
        end
      end

      cycle.after(:broadcast_success) do
        @failures = 0
      end
    end

  end
end
