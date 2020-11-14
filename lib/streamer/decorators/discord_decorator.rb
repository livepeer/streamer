module Streamer
  class DiscordDecorator
    attr_reader :discord

    def initialize(discord)
      @discord = discord
    end

    def decorate(cycle)
      c = cycle

      c.before(:start_broadcast) do
        # start_message = <<~MSG
        #   -----
        #   Starting #{cycle.duration}s broadcast to #{cycle.ingest}
        # MSG
        #
        # discord.send(
        #   content: start_message,
        #   embeds: [{
        #     title: "View on Bitmovin",
        #     url: cycle.bitmovin_url
        #   }]
        # )
      end

      c.after(:playlist_too_small) do
        discord.playlist_too_small!(c, c.current_playlist_size, c.expected_playlist_size)
      end

      c.after(:broadcast_failed) do
        discord.send(
          content: "FFMPEG exited non-zero when broadcasting to #{c.ingest}"
        )
      end
    end

  end
end
