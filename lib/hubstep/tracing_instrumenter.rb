# frozen_string_literal: true

require "active_support/notifications"

module HubStep
  # Wrapper around ActiveSupport::Notifications that records instrumented
  # blocks in HubStep.tracer.
  module TracingInstrumenter
    def self.service
      ActiveSupport::Notifications
    end

    def self.publish(name, *args)
      service.publish(name, *args)
    end

    def self.instrument(name, payload = {})
      HubStep.tracer.span(name) do |span|
        service.instrument(name, payload) do |inner_payload|
          yield inner_payload, span if block_given?
        end
      end
    end

    def self.subscribe(*args, &block)
      service.subscribe(*args, &block)
    end

    def self.subscribed(callback, *args, &block)
      service.subscribed(callback, *args, &block)
    end

    def self.unsubscribe(args)
      service.unsubscribe(args)
    end
  end
end
