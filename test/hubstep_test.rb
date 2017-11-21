# frozen_string_literal: true
require "test_helper"

class HubStepTest < HubStep::TestCases
  def test_that_it_has_a_version_number
    refute_nil ::HubStep::VERSION
  end
end
