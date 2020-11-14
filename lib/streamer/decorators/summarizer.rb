module Streamer
  class Summarizer
    attr_reader :discord
    attr_reader :logger

    def initialize(
      discord:,
      logger:
    )
      @discord = discord
      @logger = logger
    end

    def decorate(cycle)
      cycle.before(:stop_monitoring_source) do
        logger.info("Fetching monitor summary before shutdown")
        status = cycle&.analyzer&.status(cycle.source)

        # send summary to discord
        discord_status = Marshal.load(Marshal.dump(status))
        discord_status["status"]&.delete("Variants")
        discord_message = <<~MSG
          Broadcast complete. Summary for session at `"#{cycle.source}"`
          ```
          #{JSON.pretty_generate(discord_status)}
          ```
        MSG
        discord.send(content: discord_message)

        # send summary to logger
        message = <<~MSG
          Broadcast Summary:
          - ingest: "#{cycle.ingest}"
          - playback: "#{cycle.playback}"
          ```
          #{JSON.pretty_generate(status)}
          ```
        MSG
        logger.info(message)
      end
    end

  end
end

