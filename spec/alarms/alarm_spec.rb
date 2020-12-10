require 'spec_helper'

require 'timecop'
require 'streamer/alarms/alarm'

module Streamer

RSpec.describe Alarm  do
  subject(:alarm) { Alarm.new(name: "test") }

  context "initialization" do
    it { is_expected.to be_detached }
    it { is_expected.to_not be_attached }
    it { is_expected.to_not be_ok }
    it { is_expected.to_not be_triggered }
  end

  context "when alarm triggers" do
    before { alarm.trigger! }

    it { is_expected.to be_triggered }
    it { is_expected.to_not be_ok } 
  end

  context "when alarm resolves" do
    before { alarm.resolve! }

    it { is_expected.to be_ok }
    it { is_expected.to_not be_triggered } 
  end

  describe "#attach!" do
    before { alarm.attach! }

    it { is_expected.to be_attached }
    it { is_expected.to_not be_detached }
  end

  describe "#detach!" do
    before { alarm.detach! }

    it { is_expected.to be_detached }
    it { is_expected.to_not be_attached }
  end

  describe "events" do
    let(:callback) { lambda { |x| } }

    before do
      alarm.on(event, &callback)
    end

    describe "on trigger" do
      let(:event) { :triggered }

      specify "triggered callbacks are fired" do
        expect(callback).to receive(:call).with(alarm)
        alarm.trigger!
      end
    end

    describe "on resolve" do
      let(:event) { :resolved }

      specify "resolve callbacks are fired" do
        expect(callback).to receive(:call).with(alarm)
        alarm.resolve!
      end
    end

  end

end

end
