# frozen_string_literal: true

require_relative "../test_helper"
require "hubstep/failbot"
require "rack"

module HubStep
  class FailbotTest < Minitest::Test
    def test_includes_request_body_in_needles
      stub_request(:post, "http://example.com:9876/api/v0/reports").to_return(status: 400)

      tracer = new_tracer
      tracer.span("foo") { }
      tracer.flush

      report = Failbot.backend.reports.first
      assert_kind_of String, report["request_body"]
      refute_empty report["request_body"]
    end

    def new_tracer
      transport = LightStep::Transport::HTTPJSON.new(
        host: "example.com",
        port: 9876,
        encryption: LightStep::Transport::HTTPJSON::ENCRYPTION_NONE,
        access_token: "12345"
      )
      tracer = Tracer.new(transport: transport)
      tracer.enabled = true
      tracer
    end
  end
end
