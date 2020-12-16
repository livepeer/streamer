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

