module Streamer
  class Broadcaster
    attr_reader :command
    attr_reader :args

    def initialize(command, args)
      @command = command
      @args = args
    end

    def start(channel)
      Concurrent::Channel.go do
        @pid = Process.spawn(command, *args)
        _, @status = Process.wait2(@pid)
        if @status.exitstatus == 0
          channel << "success"
        elsif @status.signaled? or @status.exitstatus == 255
          channel << "killed"
        else
          channel << "failed"
        end
      end

      self
    end

    def kill
      Process.kill("TERM", @pid)
    rescue Errno::ESRCH
      # swallow
    end
  end
end
