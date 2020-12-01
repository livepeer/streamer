require_relative 'stream'
require_relative 'broadcaster'

require 'concurrent'
require 'concurrent-edge'
require 'active_support'
require 'active_support/core_ext'
require 'rspec/expectations'

require 'streamer/decorators/discord_decorator'
require 'streamer/decorators/page_on_unexpected_playlist'
require 'streamer/decorators/monitor_playlist'
require 'streamer/decorators/monitor_source'
require 'streamer/decorators/monitor_rendition'
require 'streamer/decorators/logger_decorator'

module Streamer
  class LongCycleDecorators
    def self.create(
      logger:,
      discord:,
      analyzer:,
      pagerduty:
    )
      [
        Streamer::LoggerDecorator.new(logger),
        Streamer::DiscordDecorator.new(discord),
        Streamer::MonitorPlaylist.new(logger: logger),
        Streamer::MonitorSource.new(
          analyzer: analyzer,
          logger: logger,
          discord: discord,
        ),
        Streamer::MonitorRendition.new(
          analyzer: analyzer,
          logger: logger,
          discord: discord,
        ),
        Streamer::PageOnUnexpectedPlaylist.new(pagerduty, max_failures: 3),
      ]
    end
  end
end
