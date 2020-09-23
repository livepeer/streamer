# client allows instrumentation to send info to server
require 'prometheus_exporter/client'

module StreamMonitor
  class Metrics

    def initialize(server)
      @client = PrometheusExporter::LocalClient.new(collector: server.collector)
      @total_tests = @client.register(:counter, "total_tests", "number of test streams")
      @startup_seconds = @client.register(:gauge, "test_startup_seconds", "number of test streams")
      @latency_seconds = @client.register(:gauge, "latency_seconds", "segment latency")
      @segment_duration_seconds = @client.register(:gauge, "segment_duration_seconds", "segment duration")
      @active_tests = @client.register(:gauge, "active_tests", "number of active tests")
    end

    def on_broadcast_start(session, time)
      @active_tests.observe(1)
    end

    def on_success(session)
      @total_tests.observe(1, status: "success")
    end

    def on_failure(session)
      @total_tests.observe(1, status: "failure")
    end

    def on_booted(session, startup_seconds)
      @startup_seconds.observe(startup_seconds)
    end

    def on_latency_computed(session, latency, variant)
      @latency_seconds.observe(latency, variant: variant)
    end

    def on_segment_downloaded(session, duration)
      @segment_duration_seconds.observe(duration)
    end

  end
end
