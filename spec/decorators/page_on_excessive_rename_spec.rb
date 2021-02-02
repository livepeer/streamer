require 'spec_helper'

require 'streamer/decorators/page_on_excessive_rename'
require 'timecop'

RSpec.describe Streamer::PageOnExcessiveRename do
  let(:logger) { double('logger', info: true, warn: true) }
  let(:discord) { double('discord', post: true) }
  let(:pagerduty) { double('pagerduty', trigger: true) }
  let(:max_renames) { 5 }
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

  subject(:decorator) do
    Streamer::PageOnExcessiveRename.new(
      logger: logger,
      discord: discord,
      pagerduty: pagerduty,
      max_renames: max_renames,
    )
  end

  before do
    decorator.decorate(cycle)
  end

  describe "max renames" do
    context "when initizliaed with unspecific max renames" do
      it "defaults to sane value" do
        expect(decorator.max_renames).to eq(5)
      end
    end
  end

  context "when decorator detects some renames" do
    before do
      4.times { decorator.record_rename }
    end

    it "does not send page" do
      expect(pagerduty).to_not have_received(:trigger)
    end

    it "does not log warning" do
      expect(logger).to_not have_received(:warn)
    end

    it "does not post to discord" do
      expect(discord).to_not have_received(:post)
    end
  end

  context "when decorator detects excessive renames" do
    before do
      6.times { decorator.record_rename }
    end

    it "sends page" do
      expect(pagerduty).to have_received(:trigger)
    end

    it "logs warning" do
      expect(logger).to have_received(:warn)
    end

    it "posts to discord" do
      expect(discord).to have_received(:post)
    end
  end

end
