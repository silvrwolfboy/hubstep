require_relative "../../../test_helper"
require "hubstep/internal/instrumenter/noop"

module HubStep
  class NoopTest < Minitest::Test

    def test_instrument_yields_the_payload_with_block
      instrumenter = HubStep::Internal::Instrumenter::Noop.new
      payload = {test: :payload}

      result = instrumenter.instrument("something", payload) { |x| x }
      assert_equal payload, result
    end

    def test_returns_nil_with_no_block
      instrumenter = HubStep::Internal::Instrumenter::Noop.new

      result = instrumenter.instrument("something", {})
      assert_nil result
    end
  end
end
