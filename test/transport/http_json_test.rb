# frozen_string_literal: true

require_relative "../test_helper"

module HubStep
  class HTTPJSONTest < Minitest::Test
    def default_httpjson
      default_args = {
        host: "foo",
        port: 100,
        verbose: 0,
        encryption: "bar",
        access_token: "baz",
      }
      HubStep::Transport::HTTPJSON.new(default_args)
    end

    def test_instruments_successful_report # rubocop:disable Metrics/AbcSize
      HubStep.instrumenter(instrumenter: HubStep::Internal::Instrumenter::Memory.new)
      transport = default_httpjson

      stub_request(:post, "http://foo:100/api/v0/reports")
        .to_return(status: 200, body: "", headers: {})

      transport.report({})

      event = HubStep.instrumenter.events.first

      assert_equal "lightstep.transport.report", event.name
      assert_equal Net::HTTPOK, event.result.class
      assert event.payload.key?(:request_body)
      assert event.payload.key?(:response)

      HubStep.instrumenter = nil
    end

    def test_instruments_an_error_when_reporting # rubocop:disable Metrics/AbcSize
      HubStep.instrumenter(instrumenter: HubStep::Internal::Instrumenter::Memory.new)
      error = StandardError.new
      Net::HTTP.any_instance.expects(:request).raises(error)
      transport = default_httpjson

      stub_request(:post, "http://foo:100/api/v0/reports")
        .to_return(status: 200, body: "", headers: {})

      transport.report({})

      event = HubStep.instrumenter.events.first

      assert_equal "lightstep.transport.error", event.name
      assert_nil event.result
      assert_equal error, event.payload[:error]

      HubStep.instrumenter = nil
    end
  end
end
