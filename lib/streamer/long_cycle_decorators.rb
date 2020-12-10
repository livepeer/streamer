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
require 'streamer/decorators/playlist_monitor_reporter'
require 'streamer/monitors/playlist_monitor'

module Streamer
  class LongCycleDecorators
    def self.create(
      logger:,
      discord:,
      analyzer:,
      pagerduty:
    )
      playlist_monitor = PlaylistMonitor.new

      [
        Streamer::LoggerDecorator.new(logger),
        Streamer::DiscordDecorator.new(discord),
        Streamer::MonitorPlaylist.new(
          monitor: playlist_monitor,
        ),
        Streamer::PlaylistMonitorReporter.new(
          monitor: playlist_monitor,
          discord: discord,
          logger: logger,
          pagerduty: pagerduty,
        ),
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
