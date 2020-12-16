module Streamer
  class DiscordDecorator
    attr_reader :discord

    def initialize(discord)
      @discord = discord
    end

    def decorate(cycle)
      c = cycle

      c.before(:start_broadcast) do
        start_message = <<~MSG
          -----
          Starting #{cycle.duration}s broadcast to #{cycle.ingest}
        MSG

        discord.send(
          content: start_message,
          embeds: [{
            title: "View on Bitmovin",
            url: cycle.bitmovin_url
          }]
        )
      end

      c.after(:unexpected_playlist) do
        discord.unexpected_playlist!(c, c.current_playlist_size, c.expected_playlist_size)
      end

      c.after(:broadcast_failed) do
        discord.send(
          content: "#{c.ingest_region}->#{c.playback_region} FFMPEG exited non-zero when broadcasting to #{c.ingest}"
        )
      end

      c.after(:broadcast_terminated) do
        discord.post(
          content: "#{c.ingest_region}->#{c.playback_region} FFMPEG recieved term signal. Shutting down."
        )
      end
    end

  end
end
