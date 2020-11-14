module Streamer
  class DiscordDecorator
    attr_reader :discord

    def initialize(discord)
      @discord = discord
    end

    def decorate(cycle)
      c = cycle

      c.before(:start_broadcast) do

        bitmovin_url = URI::HTTPS.build(
          host: "bitmovin.com",
          path: "/demos/stream-test",
          query: URI.encode_www_form(
            format: "hls",
            manifest: @m3u8,
          )
        ).to_s

        start_message = <<~MSG
          -----
          Starting #{cycle.duration}s broadcast to #{cycle.ingest}
        MSG

        discord.send(
          content: start_message,
          embeds: [{
            title: "View on Bitmovin",
            url: bitmovin_url
          }]
        )
      end

      c.after(:playlist_too_small) do
        discord.playlist_too_small!(c, c.current_playlist_size, c.expected_playlist_size)
      end

      c.after(:broadcast_failed) do
        discord.send(
          content: "FFMPEG exited non-zero when broadcasting to #{c.ingest} <@thedeeno>"
        )
      end
    end

  end
end
