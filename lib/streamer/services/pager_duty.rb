require 'pagerduty'

module Streamer
  class PagerDuty
    attr_reader :integration_key
    attr_reader :client
    attr_reader :component

    def initialize(integration_key:,component:)
      @component = component
      @client = ::Pagerduty.build(
        integration_key: integration_key,
        api_version: 2
      )
    end

    delegate :trigger, to: :client

    def trigger(key, options)
      return false if integration_key.nil?

      @client.incident(key).trigger(options)
    end

  end
end

