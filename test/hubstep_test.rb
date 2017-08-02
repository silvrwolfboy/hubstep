# frozen_string_literal: true
require "test_helper"

class HubStepTest < Minitest::Test

  def setup
    HubStep.instrumenter = nil
  end

  def test_that_it_has_a_version_number
    refute_nil ::HubStep::VERSION
  end

  def test_instrumenter_ivar_can_be_set
    value = "foo"
    HubStep.instrumenter = value
    assert_equal value, HubStep.instance_variable_get("@instrumenter")
  end

  def test_instrumenter_defaults_to_noop
    result = HubStep.instrumenter
    assert_equal HubStep::Internal::Instrumenter::Noop, result.class
  end

  def test_instrumenter_can_be_passed_in
    value = "foo"
    result = HubStep.instrumenter(instrumenter: value)
    assert_equal value, result
  end
end
