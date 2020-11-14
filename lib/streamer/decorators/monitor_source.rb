module Streamer
  class MonitorSource
    attr_reader :cycle
    attr_reader :analyzer
    attr_reader :logger
    attr_reader :discord

    def initialize(analyzer:,logger:,discord:)
      @analyzer = analyzer
      @logger = logger
      @discord = discord
    end

    def decorate(cycle)
      c = cycle

      c.before(:start_monitoring_source) do
        logger.info("Adding monitor at #{analyzer.host}")
      end

      c.after(:start_monitoring_source) do
        logger.info("Added monitor at #{analyzer.host}")
      end

      c.after(:booted) do
        c.fire(:start_monitoring_source) do
          analyzer.add(c.source)
        end

        c.add_cleanup_step(:stop_monitoring_source) do
          analyzer.remove(c.source)
        end
      end

      c.before(:stop_monitoring_source) do
        logger.info("Fetching monitor summary before shutdown")
        status = analyzer&.status(c.source)

        # send summary to discord
        discord_status = Marshal.load(Marshal.dump(status))
        discord_status["status"]&.delete("Variants")
        discord_message = <<~MSG
          Broadcast complete. Summary for session at `"#{c.source}"`
          ```
          #{JSON.pretty_generate(discord_status)}
          ```
        MSG
        discord.send(content: discord_message)

        # send summary to logger
        message = <<~MSG
          Broadcast Summary:
          - ingest: "#{c.ingest}"
          - playback: "#{c.playback}"
          ```
          #{JSON.pretty_generate(status)}
          ```
        MSG
        logger.info(message)
      end
    end
  end
end
