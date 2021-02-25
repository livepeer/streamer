module Streamer
  class AnalyzeStream
    attr_reader :cycle
    attr_reader :analyzer
    attr_reader :logger
    attr_reader :discord
    attr_reader :secondary_region

    def initialize(analyzer:,logger:,discord:,secondary_region:)
      @analyzer = analyzer
      @logger = logger
      @discord = discord
      @secondary_region = secondary_region
    end

    def decorate(cycle)
      c = cycle

      c.after(:booted) do
        c.fire(:start_monitoring_source) do
          logger.info("Adding monitor for #{c.source} at #{analyzer.host}")
          analyzer.add(c.source)
          logger.info("Added monitor for #{c.source} at #{analyzer.host}")
        end

        c.add_cleanup_step(:stop_monitoring_source) do
          logger.info("Removing monitor for #{c.source} at #{analyzer.host}")
          analyzer.remove(c.source)
          logger.info("Removed monitor for #{c.source} at #{analyzer.host}")
        end

        if secondary_region.present?
          secondary_playback = c.playback_url(secondary_region)

          c.fire(:start_monitoring_secondary) do
            logger.info("Adding secondary monitor for #{secondary_playback} at #{analyzer.host}")
            analyzer.add(secondary_playback)
            logger.info("Added secondary monitor for #{secondary_playback} at #{analyzer.host}")
          end

          c.add_cleanup_step(:stop_monitoring_secondary) do
            logger.info("Removing secondary monitor for #{secondary_playback} at #{analyzer.host}")
            analyzer.remove(secondary_playback)
            logger.info("Removed secondary monitor for #{secondary_playback} at #{analyzer.host}")
          end
        end
      end

      c.before(:stop_monitoring_source) do
        logger.info("Fetching monitor summary before shutdown")
        status = analyzer&.status(c.source)

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
