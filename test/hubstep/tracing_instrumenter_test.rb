# frozen_string_literal: true

require_relative "../test_helper"
require "hubstep/tracing_instrumenter"

module HubStep
  class TracingInstrumentorTest < Minitest::Test
    def setup
      @tracer = Tracer.new
      @tracer.enabled = true
      @instrumenter = TracingInstrumenter.new(@tracer)
    end

    def test_traces_instrumented_blocks
      original_payload = { bar: :baz }
      inner_payload = nil
      span = nil
      @instrumenter.instrument("foo", original_payload) do |payload|
        inner_payload = payload
        span = @tracer.bottom_span
      end

      assert_equal original_payload, inner_payload
      assert_equal "foo", span.operation_name
    end

    def test_passes_span_to_blocks
      original_payload = { bar: :baz }
      inner_payload = nil
      inner_span = nil
      @instrumenter.instrument("foo", original_payload) do |payload, span|
        inner_payload = payload
        inner_span = span
      end

      assert_equal original_payload, inner_payload
      assert_equal "foo", inner_span.operation_name
    end

    def test_sends_notifications
      event = nil
      callback = lambda do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
      end
      payload = { bar: :baz }
      ActiveSupport::Notifications.subscribed(callback, "foo") do
        @instrumenter.instrument("foo", payload)
      end

      assert_equal "foo", event.name
      assert_equal payload, event.payload
    end
  end
end
