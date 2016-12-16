# frozen_string_literal: true

module HubStep
  # Wrapper around ActiveSupport::Notifications that traces instrumented
  # blocks.
  class Instrumenter
    # Creates an Instrumenter
    #
    # tracer  - HubStep::Tracer instance
    # service - Object that provides ActiveSupport::Notifications' API (i.e.,
    #           you could just pass ActiveSupport::Notifications here, or wrap
    #           it in some other object).
    def initialize(tracer, service)
      @tracer = tracer
      @service = service
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

    attr_reader :service
  end
end
