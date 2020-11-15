module Streamer
  class PageOnUnexpectedPlaylist
    attr_reader :pagerduty

    def initialize(pagerduty)
      @pagerduty = pagerduty
    end

    def decorate(cycle)
      cycle.after(:unexpected_playlist) do
        pagerduty.trigger_unexpected_playlist(cycle)
      end
    end

  end
end
