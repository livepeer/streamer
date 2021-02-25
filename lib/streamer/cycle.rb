require_relative 'stream'
require_relative 'broadcaster'

require 'concurrent'
require 'concurrent-edge'
require 'active_support'
require 'active_support/core_ext'
require 'rspec/expectations'

module Streamer
  class Cycle

    # initialized attributes
    attr_reader :grace
    attr_reader :duration
    attr_reader :playback_region
    attr_reader :ingest_region
    attr_reader :livepeer
    attr_reader :session_name
    attr_reader :profiles
    attr_reader :broadcaster
    attr_reader :broadcaster_factory
    attr_reader :tick_interval

    # mutable attributes
    attr_reader :stream
    attr_reader :events
    attr_reader :ingest

    delegate :bitmovin_url,
      :current_playlist,
      :source,
      :playback,
      :fetch_playlist!,
      :current_playlist_size,
      :expected_playlist_size,
      :renditions,
      :playback_url,
      to: :stream

    def initialize(
      grace:,
      duration:,
      playback_region:,
      ingest_region:,
      profiles:,
      livepeer:,
      broadcaster_factory:,
      session_name: "",
      tick_interval: 2,
      decorators: []
    )
      # Set instance variables based on named parameters
      local_variables.each do |k|
        v = eval(k.to_s)
        instance_variable_set("@#{k}", v) unless v.nil?
      end

      @tick_actions = {}
      @cleanup = []
      @events = []
      @afters = {}
      @befores = {}
      @fire_stack = []

      decorators.each { |x| x.decorate(self) }
    end

    def execute
      @started_at = Time.now

      # Setup Channels
      broadcast_exited = Concurrent::Channel.new(capacity: 1)

      fire(:init) { create_stream! }
      fire(:start_broadcast) { start_broadcast(ingest, broadcast_exited) }

      booted = Concurrent::Channel.timer(grace)
      shutdown = Concurrent::Channel.new(capacity: 1)
      done = Concurrent::Channel.new(capacity: 1)

      tick = Concurrent::Channel.new(capacity: 1)
      duration_reached = Concurrent::Channel.new(capacity: 1)

      loop do
        Concurrent::Channel.select do |s|
          s.take(booted) do
            fire(:booted)

            tick = Concurrent::Channel.ticker(tick_interval)
            duration_reached = Concurrent::Channel.timer(duration)
          end

          s.take(duration_reached) do
            fire(:broadcast_success)
            shutdown << true
          end

          s.take(broadcast_exited) do |msg|
            case msg
            when "success"
              fire(:broadcast_success)
            when "killed"
              fire(:broadcast_terminated)
            when "failed"
              fire(:broadcast_failed)
            else
              fire(:broadcast_exited)
            end
            shutdown << true
          end

          s.take(shutdown) do
            shutdown!
            broadcast_exited.close
            return
          end

          s.take(tick) { tick! }
        end
      end
    end

    def decorate_with(decorator)
      decorator.decorate(self)
    end

    def add_tick_action(name, &block)
      @tick_actions[name] = block
    end

    def remove_tick_action(name)
      @tick_actions.delete(name) if @tick_actions.key? name
    end

    def elapsed
      Time.now - @started_at
    end

    def fire(event)
      @fire_stack.push event

      @befores[event].each(&:call) if @befores.key? event

      @events << @fire_stack.map(&:to_s).join("__").to_sym
      yield if block_given?

      @afters[event].reverse.each(&:call) if @afters.key? event

      @fire_stack.pop
    end

    def create_stream!
      fire(:create_stream) do
        @stream = livepeer.create_stream(
          name: SecureRandom.uuid,
          profiles: profiles,
          playback_region: playback_region,
          ingest_region: ingest_region,
        )
        @ingest = stream.rtmp_ingest_url
      end

      add_cleanup_step(:destroy_stream) do
        livepeer.delete_stream(@stream.id)
      end
    end

    def add_cleanup_step(event, &block)
      @cleanup.push([ event, block ])
    end

    def start_broadcast(ingest, exit_channel)
      @broadcaster = broadcaster_factory.create(ingest).tap do |x|
        x.start(exit_channel)
      end

      add_cleanup_step(:stop_broadcast) do
        broadcaster.kill
      end
    end

    def tick!
      fire(:tick) do
        @tick_actions.each do |k, v|
          fire(k) { v.call }
        end
      end
    end

    def after(event, &block)
      @afters[event] ||= []
      @afters[event].append block
    end

    def before(event, &block)
      @befores[event] ||= []
      @befores[event].append block
    end

    def interrupt!
      fire(:interrupt)
      shutdown!
    end

    def shutdown!
      fire(:shutdown) do
        while !@cleanup.empty?
          event, task = @cleanup.pop
          fire(event) { task.call }
        end
      end
    end
  end
end

