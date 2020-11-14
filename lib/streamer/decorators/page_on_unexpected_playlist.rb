module Streamer
  class PageOnUnexpectedPlaylist
    attr_reader :pagerduty

    def initialize(pagerduty)
      @pagerduty = pagerduty
    end

    def decorate(cycle)
      cycle.after(:playlist_too_small) do
        pagerduty.trigger_unexpected_playlist(cycle)
      end
    end

  end
end
