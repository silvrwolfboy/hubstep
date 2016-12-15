# frozen_string_literal: true

require_relative "../test_helper"
require "hubstep/tracing_instrumenter"

class TracingInstrumentorTest < Minitest::Test
  def setup
    @original_enabled = HubStep.tracer.enabled?
    @instrumenter = HubStep::TracingInstrumenter
    HubStep.tracer.enabled = true
  end

  def teardown
    HubStep.tracer.enabled = @original_enabled
  end

  def test_traces_instrumented_blocks
    original_payload = { :bar => :baz }
    inner_payload = nil
    span = nil
    @instrumenter.instrument("foo", original_payload) do |payload|
      inner_payload = payload
      span = HubStep.tracer.bottom_span
    end

    assert_equal original_payload, inner_payload
    assert_equal "foo", span.operation_name
  end

  def test_passes_span_to_blocks
    original_payload = { :bar => :baz }
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
    callback = lambda { |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
    }
    payload = { :bar => :baz }
    ActiveSupport::Notifications.subscribed(callback, "foo") do
      @instrumenter.instrument("foo", payload)
    end

    assert_equal "foo", event.name
    assert_equal payload, event.payload
  end
end
