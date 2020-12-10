require 'active_support/core_ext'
require 'chronic_duration'

module Streamer
  class BadPlaylistAlarm < Alarm
    attr_reader :events
    attr_reader :started_at

    THRESHOLD = 3.minutes

    def threshold
      THRESHOLD
    end

    def observe(event)
      @events << event

      if event == :normal
        resolve! if triggered?
      else
        start if stopped?
        trigger! if fault_duration >= threshold
      end
    end

    def initialize
      super
      @events = []
    end

    def start
      @started_at = Time.now
    end

    def stopped?
      @started_at.nil?
    end

    def started?
      !stopped?
    end

    def duration
      Time.now - started_at
    end

    def pretty_duration
      ChronicDuration.output(duration.round, format: :long, units: 1, limit_to_minutes: true)
    end

    def errors
      events.reject { |x| :normal }
    end

    def errors?
      errors.count > 0
    end
  end

end
