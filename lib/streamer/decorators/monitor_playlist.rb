require 'active_support/core_ext'

require 'chronic_duration'
require 'streamer/monitors/playlist_monitor'
require 'streamer/playlist_sampler'

module Streamer
  class MonitorPlaylist
    attr_reader :monitor
    attr_reader :cycle

    alias_method :c, :cycle

    THRESHOLD = 3.minutes

    def initialize(monitor: PlaylistMonitor.new)
      @monitor = monitor
    end

    def decorate(cycle)
      @cycle = cycle

      monitor.on(:sampled) { |m, type| c.fire("playlist_sampled_#{type}".to_sym) }
      monitor.on(:alert_started) { c.fire(:playlist_alert_started) }
      monitor.on(:alert_stopped) { c.fire(:playlist_alert_stopped) }
      monitor.on(:alarm_started) { c.fire(:playlist_alarm_started) }
      monitor.on(:alarm_stopped) { c.fire(:playlist_alarm_stopped) }

      c.before(:booted) { c.fetch_playlist! }

      c.after(:booted) do
        c.fire(:start_monitoring_playlist) do
          sampler = PlaylistSampler.new(c.stream)

          c.add_tick_action(:check_playlist) do
            monitor.record(sampler.sample)
          end
        end

        c.add_cleanup_step(:stop_monitoring_playlist) do
          monitor.shutdown
          c.remove_tick_action(:check_playlist)
        end
      end
    end
  end
end
