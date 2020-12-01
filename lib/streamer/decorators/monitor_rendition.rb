module Streamer
  class MonitorRendition
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
      active_monitors = []

      c.before(:start_monitoring_rendition) do
        logger.info("Adding rendition monitor at #{analyzer.host}")
      end

      c.after(:start_monitoring_rendition) do
        logger.info("Added rendition monitor at #{analyzer.host}")
      end

      c.after(:playlist_renamed) do
        until active_monitors.empty? 
          monitor = active_monitors.pop
          c.fire(:stop_monitoring_rendition) do
            logger.info("Removing rendition monitor for #{monitor}")
            analyzer.remove(monitor)
          end
        end

        c.fire(:start_monitoring_rendition) do
          new_rendition = c.renditions.first
          if new_rendition.present?
            active_monitors << new_rendition
            analyzer.add(new_rendition)
          end
        end
      end

      c.after(:start_monitoring_playlist) do
        c.fire(:start_monitoring_rendition) do
          rendition = c.renditions.first
          if rendition.present?
            active_monitors << rendition
            analyzer.add(rendition)
          end
        end

        c.add_cleanup_step(:stop_monitoring_rendition) do
          until active_monitors.empty? 
            monitor = active_monitors.pop
            logger.info("Removing rendition monitor for #{monitor}")
            analyzer.remove(monitor)
          end
        end
      end
    end
  end
end
