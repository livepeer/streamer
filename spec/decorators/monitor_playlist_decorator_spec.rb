require 'spec_helper'


require 'streamer/cycle'
require 'streamer/decorators/monitor_playlist'
require 'support/faker/livepeer'
require 'timecop'

RSpec.describe Streamer::MonitorPlaylist do
  let(:boot_delay) { 0 }
  let(:duration) { 12 }
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
      allow(x).to receive(:get_playlist_body) do
        x = playlists.shift

        if x.respond_to? :call
          x.call
        else
          x
        end
      end
    end
  end

  let(:a) { Faker::Livepeer.raw_full_playlist }
  let(:b) { Faker::Livepeer.raw_renamed_playlist(seed: 1) }
  let(:source_only) { Faker::Livepeer.raw_source_only_playlist }

  let(:playlists) {[
    a,
    a,
    source_only,
    -> { Timecop.freeze(4.minutes.from_now); source_only },
    b,
    b,
    b,
    b
  ]}

  let(:cycle) do
    Streamer::Cycle.new(
      grace: boot_delay,
      duration: duration,
      playback_region: playback_region,
      ingest_region: ingest_region,
      livepeer: livepeer,
      session_name: session_name,
      profiles: profiles,
      broadcaster_factory: broadcaster_factory,
      decorators: [ decorator ]
    )
  end

  subject(:decorator) { Streamer::MonitorPlaylist.new }

  it 'detects playlist changes and triggers alerts/alarms' do
    cycle.execute

    lifecycle = %i[
      init
      init__create_stream
      start_broadcast
      booted
      booted__start_monitoring_playlist

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_normal

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_source_only
      tick__check_playlist__playlist_alert_started

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_source_only
      tick__check_playlist__playlist_alarm_started

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_rename
      tick__check_playlist__playlist_alert_stopped
      tick__check_playlist__playlist_alarm_stopped

      tick
      tick__check_playlist
      tick__check_playlist__playlist_sampled_normal

      broadcast_success
      shutdown
      shutdown__stop_monitoring_playlist
      shutdown__stop_broadcast
      shutdown__destroy_stream
    ]

    expect(cycle.events).to eq(lifecycle)
  end

end
