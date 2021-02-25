require 'active_support/core_ext'
require 'chronic_duration'
require 'faraday'

module Streamer

  # This monitor tracks playlist samples and detects "bad" results. When
  # an error condition is initially encountered it transitions to an alarm state.
  # If this error condition persists for longer than the given threshold it will
  # transition to an alerting state.
  #
  # Callers use the following hooks to respond to these transitions.
  #
  # The following hooks are supported
  #   - sampled, fired after a playlist event is recorded
  #   - alarm_started
  #   - alarm_stopped
  #   - alert_started
  #   - alert_stopped
  class PlaylistMonitor
    attr_reader :events
    attr_reader :errors
    attr_reader :alert_started_at
    attr_reader :last_alert_duration
    attr_reader :last_alert_start
    attr_reader :last_alert_end
    attr_reader :threshold

    OK_EVENTS = [
      :normal,
      :rename,
    ]

    def initialize(threshold: 3.minutes)
      @events = []
      @errors = []
      @last_error_duration = nil
      @alarming = false
      @alert_started_at = nil
      @threshold = threshold

      @callbacks = {
        alert_started: [],
        alert_stopped: [],
        alarm_started: [],
        alarm_stopped: [],
        shutdown: [],
        sampled: [],
        bad_playlist: [],
      }
    end

    def on(event, &block)
      @callbacks[event] << block
    end

    def record(event)
      @callbacks[:sampled].each { |x| x.call(self, event) }

      @events << event

      if OK_EVENTS.include?(event)
        resolve if alerting?
      else
        alert(event)
      end
    end

    def shutdown
      @callbacks[:shutdown].each { |x| x.call(self) }
    end

    def alerting?
      @alert_started_at.present?
    end

    def alarming?
      @alarming
    end

    def nominal?
      !alerting?
    end

    def status
      return :alerting if alerting?

      :nominal
    end

    def start_alerting
      @alert_started_at ||= Time.now

      @callbacks[:alert_started].each { |x| x.call(self) }
    end

    def stop_alerting
      return false unless alerting?

      @callbacks[:alert_stopped].each { |x| x.call(self) }

      @alert_started_at = nil
    end

    def start_alarming
      @alarming = true

      @callbacks[:alarm_started].each { |x| x.call(self) }
    end

    def stop_alarming
      return false unless alarming?

      @alarming = false

      @callbacks[:alarm_stopped].each { |x| x.call(self) }
    end

    def pretty_duration
      ChronicDuration.output(alert_duration.round, format: :long, units: 1, limit_to_minutes: true)
    end


    def alert(event)
      @errors << event

      @callbacks[:bad_playlist].each { |x| x.call(self, event) }

      start_alerting unless alerting?

      if alert_duration >= threshold
        start_alarming unless alarming?
      end
    end

    def alert_duration
      Time.now - alert_started_at
    end

    def resolve
      @last_alert_end = Time.now
      @last_alert_start = alert_started_at
      @last_alert_duration = last_alert_end - last_alert_start

      stop_alerting
      stop_alarming

      reset
    end

    def errors?
      errors.count > 0
    end

    def reset
      @notified = false
      @alert_started_at = nil
      @errors = []
    end
  end

end

