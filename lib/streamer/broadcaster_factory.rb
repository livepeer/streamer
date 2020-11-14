require_relative 'broadcaster'

module Streamer
  class BroadcasterFactory
    def create(ingest)
      command = "ffmpeg"
      args = [
        "-hide_banner",
        "-re",
        "-fflags",
        "+genpts",
        "-stream_loop",
        "-1",
        "-i",
        "/opt/bbb_30s.ts",
        "-c",
        "copy",
        "-strict",
        "-2",
        "-bsf:a",
        "aac_adtstoasc",
        "-loglevel",
        "repeat+level+warning",
        "-f",
        "flv",
        ingest
      ]
      Broadcaster.new(command, args)
    end
  end
end

