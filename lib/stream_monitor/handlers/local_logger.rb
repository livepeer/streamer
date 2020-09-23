require 'logger'
require 'colorize'

module StreamMonitor
  class LocalLogger

    attr_reader :total
    attr_reader :success
    attr_reader :failure
    attr_reader :logger

    def initialize(io)
      @logger = Logger.new(io)
      @total = 0
      @success = 0
      @failure = 0
      @symbols = ""
      @start_time = nil
    end

    def on_broadcast_start(session, time)
      @start_time = time
      @total += 1
    end

    def on_boot(session)
      logger.info "Starting stream #{session.name}. Broadcasting for #{session.duration} to #{session.injest}"
    end

    def on_exception(session, e)
      on_failure(session)
    end

    def on_booted(session, duration)
      logger.info "Stream #{session.name} took #{duration}s to start"
    end

    def on_success(session)
      status_name = "OK".green
      logger.info "#{status_name}. Stream #{session.name} completed successfully"
      @success += 1
      @symbols << ".".green
    end

    def on_failure(session)
      @failure += 1
      @symbols << "X".red
      status_name = "FAIL".red

      if session.booted?
        fail_time = Time.now 
        streaming_time = fail_time - @start_time
        logger.info "#{status_name}. Stream #{session.name} failed after #{streaming_time.to_s.red}s."
      else
        logger.info "#{status_name}. Stream #{session.name} failed at startup."
      end
    end

    def on_complete(session)
      success_summary = "#{@success.to_s.green} #{@success_rate.to_s.green}%"
      failure_summary = "#{@failure.to_s.red} #{@failure_rate.to_s.red}%"
      logger.info "#{success_summary} | #{failure_summary} | #{@symbols}"
    end

    def on_wait(session, wait_seconds)
      logger.info "Waiting #{wait_seconds}s before starting next broadcast"
    end

    def summarize
      logger.info ""
      logger.info "Test Run Results"
      logger.info "  Success: #{@success}"
      logger.info "  Failure: #{@failure}"
      logger.info "  Total: #{@total}"
      logger.info @symbols
      logger.info ""
    end

    def success_rate
      ((@success / @total) * 100).round(2)
    end

    def failure_rate
      ((@failure / @total) * 100).round(2)
    end
  end
end




