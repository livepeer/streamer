module Streamer
  class PageMulipleNonZero
    attr_reader :pagerduty
    attr_reader :logger
    attr_reader :failures
    attr_reader :max_failures

    def initialize(pagerduty:, logger:, max_failures: 3)
      @pagerduty = pagerduty
      @logger = logger
      @max_failures = max_failures
      @failures = 0
      @paged = false
    end

    def paged?
      @paged
    end

    def decorate(cycle)
      cycle.after(:broadcast_failed) do
        @failures += 1
        logger.info("Broadcast has failed #{failures} times in a row. Will page after #{max_failures} times.")

        if failures > max_failures and !paged?
          logger.info("Max failures exceeded, paging")

          pagerduty.trigger(
            summary: "Broadcast Failed more than #{max_failures} times in a row (#{pagerduty.component})",
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
          @paged = true
        end
      end

      cycle.after(:broadcast_success) do
        reset
      end
    end

    def reset
      @failures = 0
      @paged = false
    end

  end
end
