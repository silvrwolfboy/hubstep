# frozen_string_literal: true

module HubStep
  # Wrapper around ActiveSupport::Notifications (or any object with the same
  # API) that traces instrumented blocks. Behaves identically to the underlying
  # object except that blocks passed to #instrument will be passed two
  # arguments instead of one: the payload Hash (as usual) and the Span that
  # will represent this block of code in the trace. The Span can be used to set
  # tags etc.
  #
  #   require "hubstep/instrumenter"
  #
  #   instrumenter = HubStep::Instrumenter.new(tracer, ActiveSupport::Notifications)
  #
  #   def deflate(data)
  #     # This block will be recorded as a span by the tracer and will also
  #     # generate a notification as usual.
  #     instrumenter.instrument("deflate.zlib") do |payload, span|
  #       span.set_tag("bytesize", data.bytesize)
  #       Zlib::Deflate.deflate(data)
  #     end
  #   end
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
