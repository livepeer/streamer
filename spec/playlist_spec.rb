require 'spec_helper'

require 'streamer/playlist'

module Streamer

RSpec.describe Playlist do

  subject(:playlist) { described_class.new(content) }

  let(:full_playlist) do
    content = <<~m3u8
      #EXTM3U
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      0_1/index.m3u8
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      1_1/index.m3u8
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      2_1/index.m3u8
    m3u8
  end
  let(:empty_playlist) { "" }
  let(:source_only_playlist) do
    content = <<~m3u8
      #EXTM3U
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      0_1/index.m3u8
    m3u8
  end
  let(:renamed_playlist) do
    content = <<~m3u8
      #EXTM3U
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      0_1/index.m3u8
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      3_1/index.m3u8
      #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
      4_1/index.m3u8
    m3u8
  end

  let(:error_playlist) do
    content = <<~m3u8
      #EXTM3U
      #EXT-X-ERROR: Stream open failed
      #EXT-X-ENDLIST
    m3u8
  end

  describe "#size" do
    subject { playlist.size }

    context "when full" do
      let(:content) { full_playlist }
      it { is_expected.to eq(3) }
    end

    context "when source only" do
      let(:content) { source_only_playlist }
      it { is_expected.to eq(1) }
    end

    context "when empty" do
      let(:content) { empty_playlist }
      it { is_expected.to eq(0) }
    end

    context "when error" do
      let(:content) { error_playlist }
      it { is_expected.to eq(0) }
    end
  end

  describe "#renditions" do
    subject { playlist.renditions }

    context "when full" do
      let(:content) { full_playlist }
      it do
        is_expected.to eq(%w[
          1_1/index.m3u8
          2_1/index.m3u8
        ])
      end
    end

    context "when empty" do
      let(:content) { empty_playlist }
      it { is_expected.to be_empty }
    end

    context "when error" do
      let(:content) { error_playlist }
      it { is_expected.to be_empty }
    end

    context "when source only" do
      let(:content) { source_only_playlist }
      it { is_expected.to be_empty }
    end
  end

  describe "#arb_stack_names" do
    subject { playlist.arb_stack_names }

    context "when playlist is empty" do
      let(:content) { empty_playlist }
      it { is_expected.to be_empty }
    end

    context "when playlist is error" do
      let(:content) { error_playlist }
      it { is_expected.to be_empty }
    end

    context "when full" do
      let(:content) { full_playlist }
      it do
        is_expected.to eq([
          '0_1/index.m3u8',
          '1_1/index.m3u8',
          '2_1/index.m3u8',
        ])
      end
    end
  end

  describe "#renamed?" do
    let(:a) { Playlist.new(full_playlist) }

    subject { a.renamed? b }

    context "when comparison has different rendition names" do
      let(:b) { Playlist.new(renamed_playlist) }
      it { is_expected.to be true }
    end

    context "when playlist is the same" do
      let(:b) { Playlist.new(full_playlist) }
      it { is_expected.to be false }
    end
  end

  describe "#error?" do
    let(:content) { error_playlist }
    it { is_expected.to be_error }
  end

end

end
