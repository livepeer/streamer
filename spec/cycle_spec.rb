require 'spec_helper'

require 'streamer/cycle'
require 'streamer/decorators/discord_decorator'
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
  let(:boot_time) { 0.1 }
  let(:broadcast_time) { 1 }
  let(:tick_interval) { 0.4 }
  let(:decorators) { [] }
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
    let(:broadcaster_factory) do
      double('broadcaster_factory').tap do |x|
        allow(x).to receive(:create) { Streamer::Broadcaster.new("sleep", "30") }
      end
    end

    before do
      allow(livepeer).to receive(:create_stream) { stream }
      allow(livepeer).to receive(:delete_stream).with(stream.id) { true }
    end

    context "when decorated" do
      class TestDecorator
        attr_reader :used

        def initialize
          @used = false
        end

        def decorate(cycle)
          cycle.before(:start_broadcast) { @used = true }
        end
      end

      let(:test_decorator) { TestDecorator.new }
      let(:decorators) { [ test_decorator ] }

      it "uses the decorators" do
        subject.execute
        expect(test_decorator.used).to eq(true)
      end
    end

    context "when decorators block" do
      class TestBlockingDecorator
        def decorate(cycle)
          cycle.before(:start_broadcast) { sleep 3 }
        end
      end

      let(:decorators) { [ TestBlockingDecorator.new ] }
      let(:boot_time) { 1 }
      let(:broadcast_time) { 1 }
      let(:tick_interval) { 0.4 }

      it "performs full successful broadcast cycle" do
        subject.execute

        expect(subject.events).to eq(%i[
          init
          init__create_stream
          start_broadcast
          booted
          tick
          tick
          broadcast_success
          shutdown
          shutdown__stop_broadcast
          shutdown__destroy_stream
        ])
      end
    end

    context "when we broadcast exits non-zero" do
      let(:broadcaster_factory) do
        double('broadcaster_factory').tap do |x|
          allow(x).to receive(:create) { Streamer::Broadcaster.new("sleep 0.5; exit 33") }
        end
      end

      it "performs full failed broadcast sequence" do
        subject.execute

        expect(subject.events).to eq(%i[
          init
          init__create_stream
          start_broadcast
          booted
          tick
          broadcast_failed
          shutdown
          shutdown__stop_broadcast
          shutdown__destroy_stream
        ])
      end
    end
  end
end

end
