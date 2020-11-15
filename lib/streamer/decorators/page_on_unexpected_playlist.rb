module Streamer
  class PageOnUnexpectedPlaylist
    attr_reader :pagerduty
    attr_reader :max_failures
    attr_reader :failures

    def initialize(pagerduty, max_failures: 3)
      @pagerduty = pagerduty
      @max_failures = max_failures
      @failures = 0
      @paged = false
    end

    def decorate(cycle)
      cycle.after(:unexpected_playlist) do
        @failures += 1
        if failures >= max_failures and !paged?
          pagerduty.trigger_unexpected_playlist(cycle, failures)
        end
      end

      cycle.before(:valid_playlist) do
        reset
      end
    end

    def paged?
      @paged
    end

    def reset
      @paged = false
      @failures = 0
    end

  end
end
