require 'spec_helper'

require 'streamer/cycle'
require 'stringio'
require 'logger'
require 'streamer/long_cycle_decorators'

RSpec.describe "long cycle" do
  let(:boot_delay) { 0 }
  let(:duration) { 5 }
  let(:playback_region) { 'fake_playback_region' }
  let(:ingest_region) { 'fake_ingest_region' }
  let(:session_name) { 'test_session_id' }
  let(:broadcaster_factory) do
    double('broadcaster_factory').tap do |x|
      allow(x).to receive(:create) { Streamer::Broadcaster.new("sleep", ["30"]) }
    end
  end
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
  let(:output) { StringIO.new }
  let(:logger) do
    Logger.new(output, formatter: proc {|severity, datetime, progname, msg|
      "#{severity}: #{msg}\n"
    })
  end
  let(:livepeer) do
    double('livepeer').tap do |x|
      allow(x).to receive(:base_url) { "https://anything" }
      allow(x).to receive(:create_stream) { stream }
      allow(x).to receive(:delete_stream) { true }
    end
  end
  let(:stream) do
    hash = {
      "name" => SecureRandom.uuid,
      "profiles" => profiles,
      "id" => SecureRandom.uuid,
      "stream_key" => SecureRandom.uuid,
      "playbackId" => "fake_playback",
      "user_id" => SecureRandom.uuid,
      "platform" => "test.livepeer.monster",
      "ingest_region" => ingest_region,
      "playback_region" => playback_region,
    }
    Streamer::Stream.new(hash).tap do |x|
      allow(x).to receive(:get_playlist_body) { playlists.shift }
    end
  end
  let(:pagerduty) { double('pagerduty') }
  let(:analyzer) do
    double('analyzer').tap do |x|
      allow(x).to receive(:host) { "https://hlsanalyzer.livepeer.test" }
      allow(x).to receive(:add) { true }
      allow(x).to receive(:remove) { true }
      allow(x).to receive(:status) { analyzer_status }
    end
  end
  let(:analyzer_status) do
    {
      "link": "https://mdw-cdn.livepeer.com/hls/6146vznueuscvfmk/0_1/index.m3u8",
      "status": {
        "Variants": [],
        "PlaylistStatus": "Live",
        "SegmentStatus": "Monitoring",
        "LinkID": "41acba86",
        "Outage": 28.56,
        "Buffer": 4.64,
        "Delta": 1.0,
        "Errors": 12.0,
        "Warnings": 18.0,
        "SegDuration": 4.0,
        "SegmentDownloadTime": 0.6,
        "SegmentRate": 573.0,
        "Timestamp": 1606750310.0,
        "Uptime": 18000.49,
        "PlaylistType": "Media",
        "tracks": "VIDEO,AUDIO",
        "vcodec": "h264@Main,L3.1",
        "acodec": "aac@48.0Khz,2CH",
        "vres": "854x480",
        "vfr": "30.00",
        "SequenceNumber": 0
      }
    }
  end
  let(:discord) do
    double('discord').tap do |x|
      allow(x).to receive(:send) { true }
      allow(x).to receive(:post) { true }
      allow(x).to receive(:unexpected_playlist!) { true }
    end
  end

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

  subject(:cycle) do
    Streamer::Cycle.new(
      grace: boot_delay,
      duration: duration,
      playback_region: playback_region,
      ingest_region: ingest_region,
      livepeer: livepeer,
      session_name: session_name,
      profiles: profiles,
      broadcaster_factory: broadcaster_factory,
      decorators: Streamer::LongCycleDecorators.create(
        logger: logger,
        analyzer: analyzer,
        discord: discord,
        pagerduty: pagerduty,
      )
    )
  end

  it 'works' do
    cycle.execute

    expect(cycle.events).to eq(%i[
      init
      init__create_stream

      start_broadcast

      booted
      booted__start_monitoring_source
      booted__start_monitoring_playlist
      booted__start_monitoring_playlist__start_monitoring_rendition

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_source_only
      tick__check_playlist__playlist_alert_started

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_normal
      tick__check_playlist__playlist_alert_stopped

      broadcast_success

      shutdown
      shutdown__stop_monitoring_playlist
      shutdown__stop_monitoring_rendition
      shutdown__stop_monitoring_source
      shutdown__stop_broadcast
      shutdown__destroy_stream
    ])
  end

  context "on unexpected_playlist" do
    let(:boot_delay) { 0 }
    let(:duration) { 7 }
    # FIXME: this is hardcoded and thus has no effect here, but it should
    let(:tick_interval) { 2 }
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
        good_playlist,
        bad_playlist,
        good_playlist
      ]
    end

    it 'records expected events' do
      cycle.execute

      expect(subject.events).to eq(%i[
        init
        init__create_stream
        start_broadcast
        booted
        booted__start_monitoring_source
        booted__start_monitoring_playlist
        booted__start_monitoring_playlist__start_monitoring_rendition

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_normal

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_source_only
        tick__check_playlist__playlist_alert_started

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_normal
        tick__check_playlist__playlist_alert_stopped

        broadcast_success
        shutdown
        shutdown__stop_monitoring_playlist
        shutdown__stop_monitoring_rendition
        shutdown__stop_monitoring_source
        shutdown__stop_broadcast
        shutdown__destroy_stream
      ])
    end
  end

  context "on playlist rename" do
    let(:boot_delay) { 0 }
    let(:duration) { (playlists.count - 1) * tick_interval + 1 }
    # FIXME: this is hardcoded and thus has no effect here, but it should
    let(:tick_interval) { 2 }

    let(:playlists) do
      a = <<~m3u8
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
      b = <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        5_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1043856,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        6_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=598544,RESOLUTION=640x360,FRAME-RATE=30,CODECS="avc1.4d401e,mp4a.40.2"
        7_1/index.m3u8
      m3u8
      c = <<~m3u8
        #EXTM3U
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=818544,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        0_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1923984,RESOLUTION=1280x720,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        8_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1043856,RESOLUTION=854x480,FRAME-RATE=30,CODECS="avc1.4d401f,mp4a.40.2"
        9_1/index.m3u8
        #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=598544,RESOLUTION=640x360,FRAME-RATE=30,CODECS="avc1.4d401e,mp4a.40.2"
        10_1/index.m3u8
      m3u8
      [
        a,
        a,
        b,
        b,
        c,
        c
      ]
    end

    it 'add/removes analyzers on rename', aggregate: true do
      expect(analyzer).to receive(:add).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/0_1/index.m3u8").ordered
      expect(analyzer).to receive(:add).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/2_1/index.m3u8").ordered
      expect(analyzer).to receive(:remove).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/2_1/index.m3u8").ordered
      expect(analyzer).to receive(:add).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/5_1/index.m3u8").ordered
      expect(analyzer).to receive(:remove).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/5_1/index.m3u8").ordered
      expect(analyzer).to receive(:add).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/8_1/index.m3u8").ordered
      expect(analyzer).to receive(:remove).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/8_1/index.m3u8").ordered
      expect(analyzer).to receive(:remove).with("https://fake_playback_region-cdn.test.livepeer.monster/hls/fake_playback/0_1/index.m3u8").ordered


      cycle.execute

      expect(subject.events).to eq(%i[
        init
        init__create_stream
        start_broadcast
        booted
        booted__start_monitoring_source
        booted__start_monitoring_playlist
        booted__start_monitoring_playlist__start_monitoring_rendition

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_normal

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_rename
        tick__check_playlist__playlist_sampled_rename__stop_monitoring_rendition
        tick__check_playlist__playlist_sampled_rename__start_monitoring_rendition

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_normal

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_rename
        tick__check_playlist__playlist_sampled_rename__stop_monitoring_rendition
        tick__check_playlist__playlist_sampled_rename__start_monitoring_rendition

        tick
        tick__check_playlist
        tick__check_playlist__playlist_sampled_normal

        broadcast_success
        shutdown
        shutdown__stop_monitoring_playlist
        shutdown__stop_monitoring_rendition
        shutdown__stop_monitoring_source
        shutdown__stop_broadcast
        shutdown__destroy_stream
      ])
    end
  end
end
