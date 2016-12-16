# frozen_string_literal: true

require "active_support/notifications"

module HubStep
  # Wrapper around ActiveSupport::Notifications that traces instrumented
  # blocks.
  class Instrumenter
    def initialize(tracer)
      @tracer = tracer
    end

    def publish(name, *args)
      service.publish(name, *args)
    end

    def instrument(name, payload = {})
      @tracer.span(name) do |span|
        service.instrument(name, payload) do |inner_payload|
          yield inner_payload, span if block_given?
        end
      end
    end

    def subscribe(*args, &block)
      service.subscribe(*args, &block)
    end

    def subscribed(callback, *args, &block)
      service.subscribed(callback, *args, &block)
    end

    def unsubscribe(args)
      service.unsubscribe(args)
    end

    private

    def service
      ActiveSupport::Notifications
    end
  end
end
