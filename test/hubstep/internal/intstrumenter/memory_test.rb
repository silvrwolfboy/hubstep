# frozen_string_literal: true

require_relative "../../../test_helper"
require "hubstep/internal/instrumenter/memory"

module HubStep
  class MemoryTest < Minitest::Test
    def test_instrument_yields_the_payload_with_block
      instrumenter = HubStep::Internal::Instrumenter::Memory.new
      payload = { test: :payload }

      result = instrumenter.instrument("something", payload) { |x| x }
      assert_equal payload, result
    end

    def test_returns_nil_with_no_block
      instrumenter = HubStep::Internal::Instrumenter::Memory.new

      result = instrumenter.instrument("something", {})
      assert_nil result
    end

    def test_records_events
      instrumenter = HubStep::Internal::Instrumenter::Memory.new
      payload = { test: :payload }

      result = instrumenter.instrument("something", payload) { |x| x }
      event = instrumenter.events.first
      assert_equal HubStep::Internal::Instrumenter::Memory::Event, event.class
      assert_equal "something", event.name
      assert_equal payload, event.payload
      assert_equal result, event.result
    end
  end
end
