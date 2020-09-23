require 'ruby-units'
require 'open3'
require 'time'
require 'securerandom'

module StreamMonitor

  # Wraps a stream-tester subprocess with log and process monitoring and transforms
  # activity into events to be handled by the given handlers
  #
  # Emits the following events:
  #   - on_boot
  #   - on_playback_start
  #   - on_broadcast_start
  #   - on_booted
  #   - on_latency_computed
  #   - on_segment_downloaded
  #   - on_line
  #   - on_success
  #   - on_failure
  #   - on_complete
  #   - on_exception
  #
  class Session
    PROCESSORS = {
      latency: /] (\d+x\d+) seqNo.*latency is ([^\s]+)/,
      segment_duration: /segment duration ([^\s]+)/,
      boot_start: /Starting infinite stream/,
      boot_complete: /Downloading segment/,
    }

    attr_reader :booted
    attr_reader :booting
    attr_reader :processors
    attr_reader :boot_start
    attr_reader :boot_latency
    attr_reader :command
    attr_reader :handlers
    attr_reader :wait_seconds
    attr_reader :args
    attr_reader :name

    def initialize(
      command: "/opt/stream_tester",
      args: [],
      handlers: [],
      wait_seconds: 60
    )
      @booting = false
      @booted = false
      @boot_start = nil
      @playback_start = nil
      @wait_seconds = wait_seconds

      @command = command
      @args = args
      @handlers = handlers
      @processors = PROCESSORS
      @name ||= SecureRandom.uuid
    end

    def start
      Open3.popen2e(command, *args) do |i, oe, t|
        oe.each do |line|
          emit(:on_line, line)

          processors.each do |k, pattern|
            match = line.match(pattern)
            send(k, line, match) if match
          end
        end

        exit_status = t.value

        if exit_status.success?
          emit(:on_success)
        else
          emit(:on_failure)
        end

        emit(:on_complete)
      end

      emit(:on_wait, wait_seconds)
      sleep wait_seconds
    rescue StandardError => e
      emit(:on_exception, e)
      raise e
    end

    def emit(event, *args)
      @handlers.each do |h|
        h.send(event, self, *args) if h.respond_to? event
      end
    end

    def boot_start(line, _match)
      return if booted

      @booting = true
      @boot_start = parse_time(line)

      emit(:on_broadcast_start, @boot_start)
    end

    def boot_complete(line, _match)
      return unless booting

      @booting = false
      @booted = true
      @playback_start = parse_time(line)
      boot_latency = (@playback_start - @boot_start).to_f

      emit(:on_playback_start, @playback_start)
      emit(:on_booted, boot_latency)
    end

    def latency(line, match)
      variant = match[1]
      latency = Unit.new(match[2]).convert_to("seconds").scalar.to_f
      emit(:on_latency_computed, latency, variant)
    end

    def segment_duration(line, match)
      duration = Unit.new(match[1]).convert_to("seconds").scalar.to_f
      emit(:on_segment_downloaded, duration)
    end

    def booted?
      @booted
    end

    private

    def parse_time(line)
      Time.parse(line.split(" ")[1])
    end

  end

end
