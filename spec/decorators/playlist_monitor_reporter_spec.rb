require 'spec_helper'

require 'streamer/monitors/playlist_monitor'
require 'streamer/decorators/playlist_monitor_reporter'
require 'active_support/core_ext'
require 'timecop'
require 'logger'

module Streamer

RSpec.describe PlaylistMonitorReporter  do
  let(:logger) { double('logger', info: true, warn: true) }
  let(:discord) { double('discord', post: true) }
  let(:pagerduty) { double('pagerduty', trigger: true) }
  let(:cycle) do
    double('cycle', {
      ingest_region: 'fra',
      playback_region: 'mdw',
      before: true,
      after: true,
      booted: true,
      session_name: "fake-session-id",
      ingest: "fake-ingest-url",
      playback: "fake-ingest-url",
      bitmovin_url: "fake-bitmovin-url",
      profiles: []
    })
  end
  let(:monitor) do
    PlaylistMonitor.new
  end
  let(:decorator) do
    PlaylistMonitorReporter.new(
      logger: logger,
      discord: discord,
      pagerduty: pagerduty,
      monitor: monitor,
    )
  end

  before do
    decorator.decorate(cycle)
  end

  context "when playlist is renamed" do
    before { monitor.record(:rename) }

    specify "discord is notified" do
      expect(discord).to have_received(:post)
    end
  end

  context "when alert starts" do
    before { monitor.start_alerting }

    specify "discord is notified" do
      expect(discord).to have_received(:post)
    end

    specify "pagerduty is not notified" do
      expect(pagerduty).to_not have_received(:trigger)
    end

    specify "message is logged" do
      expect(logger).to have_received(:warn)
    end

    context "when bad playlists continue to be seen" do
      let(:error_count) { 3 }
      before do
        error_count.times { monitor.record(:bod) }
      end

      specify "discord is not notified" do
        expect(discord).to_not receive(:post)
      end

      specify "pagerduty is not notified" do
        expect(pagerduty).to_not receive(:trigger)
      end

      specify "message is logged for each error" do
        expect(logger).to have_received(:warn).at_least(error_count).times
      end
    end

    context "and the monitor observes some errors" do
      let(:error_count) { 3 }
      before do
        error_count.times { monitor.record(:bod) }
      end

      context "when alert resolves" do
        before do
          Timecop.travel(2.seconds.from_now) do
            monitor.stop_alerting
          end
        end

        specify "discord is notified with error summary" do
          message = <<~MSG.chomp
            Cycle (fra->mdw) experienced bad playlists (3x) for 2 seconds. Normal playlists have resumed.
          MSG

          expect(discord).to have_received(:post).with(content: message)
        end

        specify "pagerduty is not notified" do
          expect(pagerduty).to_not have_received(:trigger)
        end
      end
    end

  end

  context "when alarm starts" do
    let(:error_count) { 3 }

    before do
      monitor.start_alerting

      error_count.times { monitor.record(:bod) }

      Timecop.travel(3.minutes.from_now) { monitor.start_alarming }
    end

    specify "discord is notified" do
      message = <<~MSG.chomp
        Cycle (fra->mdw) has been experiencing bad playlists (3x) for over 3 minutes.
      MSG

      expect(discord).to have_received(:post).with(content: message)
    end

    specify "pagerduty is notified" do
      expect(pagerduty).to have_received(:trigger)
    end
  end

  describe "lifecycles" do
    let(:decorator) do
      PlaylistMonitorReporter.new(
        logger: logger,
        discord: discord,
        pagerduty: pagerduty,
        monitor: monitor,
      )
    end
    let(:output) { StringIO.new }
    let(:logger) do
      Logger.new(output, formatter: proc {|severity, datetime, progname, msg|
        "#{severity}: #{msg}\n"
      })
    end

    context "normal playlists after alarm" do
      before do
        monitor.record(:normal)
        monitor.record(:bad)
        monitor.record(:bad)

        Timecop.freeze(3.minutes.from_now)

        monitor.record(:bad)

        Timecop.freeze(3.minutes.from_now)

        monitor.record(:bad)
        monitor.record(:bad)
        monitor.record(:normal)
      end

      specify "logs messages at each stage" do
        expected = <<~OUTPUT
          WARN: bad
          WARN: Cycle (fra->mdw) has experienced a bad playlist.
          WARN: bad
          WARN: bad
          WARN: Cycle (fra->mdw) has been experiencing bad playlists (3x) for over 3 minutes.
          WARN: bad
          WARN: bad
          WARN: Cycle (fra->mdw) experienced bad playlists (5x) for 6 minutes. Normal playlists have resumed.
        OUTPUT
        output.rewind
        expect(output.read).to eq(expected)
      end
    end

    context "shutting down after alarm" do
      before do
        monitor.start_alerting

        3.times { monitor.record(:bad) }

        Timecop.travel(3.minutes.from_now) { monitor.start_alarming }

        Timecop.travel(6.minutes.from_now) do
          2.times { monitor.record(:bad) }
          monitor.shutdown
        end
      end

      specify "logs messages at each stage" do
        expected = <<~OUTPUT
          WARN: Cycle (fra->mdw) has experienced a bad playlist.
          WARN: bad
          WARN: bad
          WARN: bad
          WARN: Cycle (fra->mdw) has been experiencing bad playlists (3x) for over 3 minutes.
          WARN: bad
          WARN: bad
          WARN: Cycle (fra->mdw) experienced bad playlists (5x) for 6 minutes before shutdown.
        OUTPUT
        output.rewind
        expect(output.read).to eq(expected)
      end
    end

  end

end

end
