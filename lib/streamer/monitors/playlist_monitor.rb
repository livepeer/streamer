require 'active_support/core_ext'
require 'chronic_duration'
require 'faraday'

module Streamer

  class PlaylistMonitor
    attr_reader :events
    attr_reader :errors
    attr_reader :alert_started_at
    attr_reader :last_alert_duration
    attr_reader :last_alert_start
    attr_reader :last_alert_end
    attr_reader :stream

    THRESHOLD = 3.minutes
    OK_EVENTS = [
      :normal,
      :rename,
    ]

    def initialize
      @events = []
      @errors = []
      @last_error_duration = nil
      @alarming = false
      @alert_started_at = nil

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

    def watch(stream)
      @stream = stream
    end

    def sample!
      sample = stream.fetch_playlist!

      if sample.source_only?
        record(:source_only)
      elsif sample.nil?
        record(:null)
      else
        if sample.renamed?(@last_normal_playlist)
          record(:rename)
        else
          record(:normal)
        end

        @last_normal_playlist = sample
      end
    rescue Faraday::ConnectionFailed => e
      record(:conection_failed_error)
    rescue Faraday::TimeoutError => e
      record(:timeout_error)
    rescue Faraday::ClientError => e
      record(:client_error)
    rescue Faraday::ServerError => e
      record(:server_error)
    end

    def threshold
      THRESHOLD
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

