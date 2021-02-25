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
  class ShortCycleDecorators
    def self.create(
      logger:,
      discord:,
      pagerduty:,
      max_non_zero_exists: 3
    )
      playlist_monitor = PlaylistMonitor.new(threshold: 30.seconds)

      [
        Streamer::LoggerDecorator.new(logger),
        Streamer::MonitorPlaylist.new(
          monitor: playlist_monitor,
        ),
        Streamer::PlaylistMonitorReporter.new(
          monitor: playlist_monitor,
          discord: discord,
          logger: logger,
          pagerduty: pagerduty,
        ),
        Streamer::PageMulipleNonZero.new(
          pagerduty: pagerduty,
          logger: logger,
          max_failures: max_non_zero_exists,
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
