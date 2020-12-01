module Streamer
  class Playlist
    attr_reader :raw

    ARB_STACK_NAMES_PATTERN = /#EXT-X-STREAM[^\n]*\n(\S+)/m
    SOURCE_PATTERN = /^0_1/

    def initialize(raw)
      @raw = raw
    end

    def arb_stack_names
      return [] if raw.nil?
      [raw.scan(ARB_STACK_NAMES_PATTERN)].flatten
    end

    def size
      arb_stack_names.length
    end

    def renditions
      arb_stack_names.reject { |x| x.match(SOURCE_PATTERN) }
    end

    def rendition_count
      renditions.count
    end

    def renamed?(b)
      renditions != b.renditions
    end
  end
end

