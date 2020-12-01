require 'spec_helper'

require 'streamer/cycle'
require 'stringio'
require 'logger'
require 'streamer/decorators/discord_decorator'
require 'streamer/decorators/page_on_unexpected_playlist'
require 'streamer/decorators/monitor_playlist'

module Streamer

RSpec.describe Cycle do
  subject do
    described_class.new(
      grace: boot_time,
      duration: broadcast_time,
      playback_region: "mdw",
      ingest_region: "mdw",
      profiles: profiles,
      livepeer: livepeer,
      tick_interval: tick_interval,
      broadcaster_factory: broadcaster_factory,
      decorators: decorators,
    )
  end
  let(:discord) { double('discord', send: true) }
  let(:boot_time) { 0.1 }
  let(:broadcast_time) { 1 }
  let(:tick_interval) { 0.4 }
  let(:logger) do
    Logger.new(output, formatter: proc {|severity, datetime, progname, msg|
      "#{severity}: #{msg}\n"
    })
  end
  let(:decorators) { [] }
  let(:output) { StringIO.new }
  let(:profiles) do
    [
      {
        "name": "720p",
        "bitrate": 2000000,
        "fps": 30,
        "width": 1280,
        "height": 720
      },
      {
        "name": "480p",
        "bitrate": 1000000,
        "fps": 30,
        "width": 854,
        "height": 480
      },
      {
        "name": "360p",
        "bitrate": 500000,
        "fps": 30,
        "width": 640,
        "height": 360
      }
    ]
  end
  let(:livepeer) { double('livepeer') }

  describe "#execute" do
    let(:stream) do
      double('stream', {
        id: SecureRandom.uuid,
        rtmp_ingest_url: "",
        playback_url: "",
        name: "",
        destroy!: true,
        source: "",
        fetch_playlist_size: 4
      })
    end
    let(:analyzer) do
      double('analyzer').tap do |x|
        allow(x).to receive(:add) { true }
        allow(x).to receive(:remove) { true }
        allow(x).to receive(:status) { true }
      end
    end
    let(:available_broadcast_seconds) { 5 }
    let(:broadcaster_factory) do
      double('broadcaster_factory').tap do |x|
        allow(x).to receive(:create) { Streamer::Broadcaster.new("sleep", "30") }
      end
    end

    before do
      allow(livepeer).to receive(:create_stream) { stream }
      allow(livepeer).to receive(:delete_stream).with(stream.id) { true }
    end

    context "when we reach cycle time without error" do
      let(:available_broadcast_seconds) { 5 }
      let(:boot_time) { 1 }
      let(:broadcast_time) { 1 }
      let(:tick_interval) { 0.4 }

      it "performs expected sequence" do
        subject.execute

        expect(subject.events).to eq(%i[
          init
          init__create_stream
          start_broadcast
          booted
          start_monitoring_source
          start_monitoring_playlist
          tick
          tick__check_playlist
          tick
          tick__check_playlist
          shutdown
          shutdown__stop_monitoring_playlist
          shutdown__stop_monitoring_source
          shutdown__stop_broadcast
          shutdown__destroy_stream
        ])
      end
    end

    context "when decorated" do
      class TestDecorator
        attr_reader :logger

        def initialize(logger)
          @logger = logger
        end

        def decorate(cycle)
          cycle.before(:start_broadcast) do
            logger.info "starting..."
          end

          cycle.after(:start_broadcast) do
            logger.info "started"
          end
        end
      end

      let(:decorators) { [ TestDecorator.new(logger) ] }

      it "uses the decorators" do
        subject.execute

        output.rewind
        expected = <<~OUT
          INFO: starting...
          INFO: started
        OUT

        expect(output.read).to eq(expected)
      end
    end

    context "when playlist is changes" do
      let(:available_broadcast_seconds) { 5 }
      let(:boot_time) { 1 }
      let(:broadcast_time) { 1 }
      let(:tick_interval) { 0.4 }
      let(:decorators) { [ ] }
      let(:pagerduty) { double('Streamer::PagerDuty') }
      let(:playlists) do
        good_playlist = <<~m3u8
          #EXTM3U
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
          0_1/index.m3u8
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
          2_1/index.m3u8
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1043856,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
          3_1/index.m3u8
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=598544,RESOLUTION=640x360,FRAME-RATE=30,CODECS="avc1.4d401e,mp4a.40.2"
          4_1/index.m3u8
        m3u8
        bad_playlist = <<~m3u8
          #EXTM3U
          #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
          0_1/index.m3u8
        m3u8
        [
          good_playlist,
          bad_playlist,
          good_playlist
        ]
      end

      let(:stream) do
        Stream.new(
          name: "",
        )
      end

      before do
        allow(stream).to receive(:fetch_playlist!) { true }

        allow(stream).to receive(:current_playlist) do
          playlists.shift
        end
      end

      it "notifies discord" do
        subject.decorate_with(Streamer::DiscordDecorator.new(discord))

        expect(discord).to receive(:unexpected_playlist!).once

        subject.execute
      end

      it "notifies pagerduty" do
        subject.decorate_with(MonitorPlaylist.new(logger: logger))
        subject.decorate_with(PageOnUnexpectedPlaylist.new(pagerduty, max_failures: 2))

        expect(pagerduty).to receive(:trigger_unexpected_playlist).once

        subject.execute
      end
    end

    context "when decorators block" do
      class TestBlockingDecorator
        def decorate(cycle)
          cycle.before(:start_broadcast) { sleep block_time }
        end
      end

      let(:block_time) { 3 }
      let(:decorators) { [ TestBlockingDecorator.new ] }
      let(:available_broadcast_seconds) { 2 }
      let(:boot_time) { 1 }
      let(:broadcast_time) { 1 }
      let(:tick_interval) { 0.4 }

      it "performs expected sequence" do
        subject.execute

        expect(subject.events).to eq(%i[
          init
          init__create_stream
          start_broadcast
          booted
          start_monitoring_source
          start_monitoring_playlist
          tick
          tick__check_playlist
          tick
          tick__check_playlist
          shutdown
          shutdown__stop_monitoring_playlist
          shutdown__stop_monitoring_source
          shutdown__stop_broadcast
          shutdown__destroy_stream
        ])
      end
    end

    context "when we broadcast exits non-zero" do
      let(:broadcaster_factory) { FakeBroadcasterFactory.new("sleep 0.5; exit 33") }

      it "performs expected sequence" do
        subject.execute

        expect(subject.events).to eq(%i[
          init
          init__create_stream
          start_broadcast
          booted
          start_monitoring_source
          start_monitoring_playlist
          tick
          tick__check_playlist
          broadcast_failed
          shutdown
          shutdown__stop_monitoring_playlist
          shutdown__stop_monitoring_source
          shutdown__stop_broadcast
          shutdown__destroy_stream
        ])
      end
    end
  end
end

end
