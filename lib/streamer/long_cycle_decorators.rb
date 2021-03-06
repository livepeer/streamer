require_relative 'stream'
require_relative 'broadcaster'

require 'concurrent'
require 'concurrent-edge'
require 'active_support'
require 'active_support/core_ext'
require 'rspec/expectations'

require 'streamer/decorators/discord_decorator'
require 'streamer/decorators/page_on_excessive_rename'
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
      pagerduty:,
      secondary_region: nil
    )
      playlist_monitor = PlaylistMonitor.new(threshold: 3.minutes)

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
        Streamer::AnalyzeStream.new(
          analyzer: analyzer,
          logger: logger,
          discord: discord,
          secondary_region: secondary_region,
        ),
        Streamer::MonitorRendition.new(
          analyzer: analyzer,
          logger: logger,
          discord: discord,
        ),
        Streamer::PageOnExcessiveRename.new(
          logger: logger,
          discord: discord,
          pagerduty: pagerduty,
          max_renames: 10,
        )
      ]
    end
  end
end
