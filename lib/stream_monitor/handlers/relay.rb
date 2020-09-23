module StreamMonitor
  class Relay
    def initialize(io)
      @io = io
    end

    def on_line(session, line)
      @io.puts line
    end
  end
end
