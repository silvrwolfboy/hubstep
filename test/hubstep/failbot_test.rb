# frozen_string_literal: true

require_relative "../test_helper"
require "hubstep/failbot"
require "rack"

module HubStep
  class FailbotTest < Minitest::Test
    def setup
      Failbot.backend = Failbot::MemoryBackend.new
    end

    def test_reports_http_client_errors_to_failbot # rubocop:disable Metrics/AbcSize
      stub_request(:post, "http://example.com:9876/api/v0/reports").to_return(status: 400)

      tracer = new_tracer
      tracer.span("foo") { }
      tracer.flush

      report = Failbot.backend.reports.last
      assert_kind_of String, report["request_body"]
      refute_empty report["request_body"]
      assert_kind_of String, report["response_body"]
      refute_empty report["response_body"]
      assert_kind_of String, report["response_uri"]
      refute_empty report["response_uri"]
      assert_equal "lightstep", report["app"]
      assert_equal "LightStep::Transport::HTTPJSON::Failbot::HTTPError",
                   report["class"]
    end

    def test_reports_http_server_errors_to_failbot # rubocop:disable Metrics/AbcSize
      stub_request(:post, "http://example.com:9876/api/v0/reports").to_return(status: 500)

      tracer = new_tracer
      tracer.span("foo") { }
      tracer.flush

      report = Failbot.backend.reports.last
      assert_kind_of String, report["request_body"]
      refute_empty report["request_body"]
      assert_kind_of String, report["response_body"]
      refute_empty report["response_body"]
      assert_kind_of String, report["response_uri"]
      refute_empty report["response_uri"]
      assert_equal "lightstep", report["app"]
      assert_equal "LightStep::Transport::HTTPJSON::Failbot::HTTPError",
                   report["class"]
    end

    def test_reports_exceptions_to_failbot # rubocop:disable Metrics/AbcSize
      stub_request(:post, "http://example.com:9876/api/v0/reports")
        .to_raise(Errno::ECONNREFUSED.new)

      tracer = new_tracer
      tracer.span("foo") { }
      tracer.flush

      report = Failbot.backend.reports.last
      assert_kind_of String, report["request_body"]
      refute_empty report["request_body"]
      assert_equal "lightstep", report["app"]
      assert_equal "Errno::ECONNREFUSED", report["class"]
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
