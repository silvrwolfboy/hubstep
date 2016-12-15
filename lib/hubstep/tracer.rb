# frozen_string_literal: true

require "English"
require "lightstep"
require "singleton"

module HubStep
  # Tracer wraps LightStep::Tracer. It provides a block-based API for creating
  # and configuring spans and support for enabling and disabling tracing at
  # runtime. A global instance is available via HubStep.tracer.
  class Tracer
    def initialize(transport: default_transport, tags: {})
      name = HubStep.server_metadata.values_at("app", "role").join("-")

      default_tags = {
        "hostname" => HubStep.hostname,
      }

      @tracer = LightStep::Tracer.new(component_name: name,
                                      transport: transport,
                                      tags: default_tags.merge(tags))
      @spans = []
      self.enabled = false
    end

    def enabled?
      !!@enabled
    end

    attr_writer :enabled

    def with_enabled(value)
      original = enabled?
      self.enabled = value
      yield
    ensure
      self.enabled = original
    end

    def top_span
      span = @spans.first if enabled?
      span || InertSpan.instance
    end

    def bottom_span
      span = @spans.last if enabled?
      span || InertSpan.instance
    end

    def span(operation_name, start_time: nil, tags: nil, finish: true)
      unless enabled?
        return yield InertSpan.instance
      end

      span = @tracer.start_span(operation_name,
                                child_of: @spans.last,
                                start_time: start_time,
                                tags: tags)
      @spans << span

      begin
        yield span
      ensure
        record_exception(span, $ERROR_INFO) if $ERROR_INFO

        remove(span)

        span.finish if finish && span.end_micros.nil?
      end
    end

    def record_exception(span, exception)
      span.configure do
        span.set_tag("error", true)
        span.set_tag("error.class", exception.class.name)
        span.set_tag("error.message", exception.message)
      end
    end

    def flush
      @tracer.flush if enabled?
    end

    private

    def default_transport
      host = ENV["LIGHTSTEP_COLLECTOR_HOST"]
      port = ENV["LIGHTSTEP_COLLECTOR_PORT"]
      encryption = ENV["LIGHTSTEP_COLLECTOR_ENCRYPTION"]
      access_token = ENV["LIGHTSTEP_ACCESS_TOKEN"]

      if host && port && encryption && access_token
        LightStep::Transport::HTTPJSON.new(host: host,
                                           port: port.to_i,
                                           encryption: encryption,
                                           access_token: access_token)
      else
        LightStep::Transport::Nil.new
      end
    end

    def remove(span)
      if span == @spans.last
        # Common case
        @spans.pop
      else
        @spans.delete(span)
      end
    end

    class InertSpan
      include Singleton
      self.instance.freeze

      def configure
      end

      def operation_name=(name)
      end

      def set_tag(key, value)
        self
      end

      def set_baggage_item(key, value)
        self
      end

      def get_baggage_item(key, value)
        nil
      end

      def log(event: nil, timestamp: nil, **fields)
        nil
      end

      def finish(end_time: nil)
      end
    end
  end
end

class LightStep::Span
  module Configurable
    def configure
      yield self
    end
  end

  include Configurable
end
