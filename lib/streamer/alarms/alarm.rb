require 'active_support/core_ext'
require 'chronic_duration'

module Streamer

  class Alarm
    attr_reader :events
    attr_reader :alarm_started_at
    attr_reader :status
    attr_reader :name

    def initialize(name:)
      @events = []
      @name = name

      @callbacks = {
        triggered: [],
        resolved: [],
        attached: [],
        detached: [],
      }
    end

    def on(event, &block)
      @callbacks[event] << block
    end

    def observe(event)
      # noop
    end

    def shutdown
      @callbacks[:disconnected].each { |x| x.call(self) }
    end

    def trigger!
      @status = :triggered
      fire(:triggered)
    end

    def resolve!
      @status = :ok
      fire(:resolved)
    end

    def triggered?
      @status == :triggered
    end

    def ok?
      @status == :ok
    end

    def detached?
      !@attached
    end

    def attached?
      @attached
    end

    def attach!
      @attached = true
      fire(:attached)
    end

    def detach!
      @attached = false
      fire(:detached)
    end

    def fire(event)
      @callbacks[event].each { |x| x.call(self) }
    end

    def inspect
      "Alarm:#{name}"
    end
  end

end
