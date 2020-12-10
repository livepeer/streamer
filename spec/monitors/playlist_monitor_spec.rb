require 'spec_helper'

require 'streamer/monitors/playlist_monitor'
require 'support/timeline'
require 'active_support/core_ext'
require 'timecop'

module Streamer

RSpec.describe PlaylistMonitor do
  let(:threshold) { MonitorPlaylist::THRESHOLD }
  let(:bad) { source_only_playlist }
  let(:timeline) { Timeline.new }

  after { timeline.return }

  subject(:monitor) { PlaylistMonitor.new }

  before do
    allow(monitor).to receive(:start_alerting).and_call_original
    allow(monitor).to receive(:stop_alerting).and_call_original
    allow(monitor).to receive(:start_alarming).and_call_original
    allow(monitor).to receive(:stop_alarming).and_call_original
    allow(monitor).to receive(:shutdown).and_call_original
  end

  context "when many normal playlists are seen" do
    let(:count) { 3 }
    let(:separation) { 1.second }

    before do
      timeline.add_many(:normal, count: count, separation: separation)
      timeline.play(monitor)
    end

    it "records events" do
      expect(monitor.events.count).to eq(count)
    end

    it "is ok" do
      expect(monitor.status).to eq(:nominal)
    end
  end

  context "when bad playlist is seen" do
    before do
      timeline.add(:source_only)
      timeline.play(monitor)
    end

    it "starts alerting", aggregate_errors: true do
      expect(monitor.alert_started_at).to_not be_nil
      expect(monitor.status).to eq(:alerting)
      expect(monitor).to have_received(:start_alerting).once
    end

    it "records error" do
      expect(monitor.errors.count).to eq(1)
    end

    context "when normal playlists resume" do
      before do
        timeline
          .fwd(1.second)
          .add(:normal)
        timeline.play(monitor)
      end

      it "stops alerting" do
        expect(monitor).to have_received(:stop_alerting).once
      end

      it "alert is resolved", aggregate_errors: true do
        expect(monitor.alert_started_at).to be_nil
        expect(monitor.status).to eq(:nominal)
      end

      it "alert duration is remembered" do
        expect(monitor.last_alert_duration).to eq(1.seconds)
      end
    end
  end

  context "when alerting for less than threshold" do
    before do
      timeline
        .add(:bad)
        .add(:bad)
        .add(:bad)
    end

    specify "alarming status is false" do
      timeline.play(monitor)
      expect(monitor.alarming?).to eq(false)
    end

    context "and normal playlists resume" do
      before do
        timeline.add(:normal)
        timeline.play(monitor)
      end

      it { is_expected.to_not be_alerting }
      it { is_expected.to be_nominal }

      it "remembers last alert duration" do
        expect(monitor.last_alert_duration).to be_present
      end

      it "remembers last alert duration" do
        expect(monitor.last_alert_duration).to be_present
      end
    end
  end

  context "when alert condition lasts longer than threshold" do
    let(:timeline) { Timeline.new }

    before do
      timeline
        .add(:bad)
        .fwd(monitor.threshold + 1.second)
    end

    context "and a bad playlists is seen" do
      before { timeline.add(:bad) }
    end

    context "and many bad playlists are seen" do
    end
  end
end

end
