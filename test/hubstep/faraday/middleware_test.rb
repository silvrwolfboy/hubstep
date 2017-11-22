# frozen_string_literal: true

require_relative "../../test_helper"
require "hubstep/faraday/middleware"

module HubStep
  module Faraday
    class MiddlewareTest < HubStep::TestCases
      def setup
        @reports = []
        callback = ->(report) { @reports << report }
        transport = LightStep::Transport::Callback.new(callback: callback)
        @tracer = Tracer.new(transport: transport)
        @tracer.enabled = true

        @stubs = ::Faraday::Adapter::Test::Stubs.new
        @faraday = ::Faraday.new do |b|
          b.request(:hubstep, @tracer)
          b.adapter(:test, @stubs)
        end
      end

      def test_can_configure_the_uri_parser
        assert_equal URI, HubStep::Faraday::Middleware.uri_parser

        HubStep::Faraday::Middleware.uri_parser = "test"

        assert_equal "test", HubStep::Faraday::Middleware.uri_parser

        # reset to the default
        HubStep::Faraday::Middleware.uri_parser = :default
      end

      def test_traces_requests
        @stubs.get("http://user:password@test.com/foo") { [202, {}, "bar"] }
        @faraday.get("http://user:password@test.com/foo")
        @stubs.verify_stubbed_calls
        @tracer.flush

        span = @reports.dig(0, :span_records, 0)
        assert_equal "Faraday GET", span[:span_name]
        tags = [
          { Key: "component", Value: "faraday" },
          { Key: "http.domain", Value: "test.com" },
          { Key: "http.method", Value: "GET" },
          { Key: "http.status_code", Value: "202" },
        ]
        assert_equal tags, span[:attributes].sort_by { |a| a[:Key] }
      end

      def test_adds_error_tag_for_error_status_codes
        @stubs.get("http://user:password@test.com/foo") { [404, {}, "bar"] }
        @faraday.get("http://user:password@test.com/foo")
        @stubs.verify_stubbed_calls
        @tracer.flush

        span = @reports.dig(0, :span_records, 0)
        assert_includes(span[:attributes], Key: "error", Value: "true")
      end

      def test_traces_requests_that_raise
        @stubs.get("http://user:password@test.com/foo") do
          raise ::Faraday::Error::TimeoutError, "request timed out"
        end

        assert_raises ::Faraday::Error::TimeoutError do
          @faraday.get("http://user:password@test.com/foo")
        end
        @stubs.verify_stubbed_calls
        @tracer.flush

        span = @reports.dig(0, :span_records, 0)
        assert_equal "Faraday GET", span[:span_name]
        tags = [
          { Key: "component", Value: "faraday" },
          { Key: "error", Value: "true" },
          { Key: "error.class", Value: "Faraday::TimeoutError" },
          { Key: "error.message", Value: "request timed out" },
          { Key: "http.domain", Value: "test.com" },
          { Key: "http.method", Value: "GET" },
        ]
        assert_equal tags, span[:attributes].sort_by { |a| a[:Key] }
      end

      def test_includes_url_tag_when_specified
        faraday = ::Faraday.new do |b|
          b.request(:hubstep, @tracer, include_urls: true)
          b.adapter(:test, @stubs)
        end

        @stubs.get("http://user:password@test.com/foo") { [202, {}, "bar"] }
        faraday.get("http://user:password@test.com/foo")

        @stubs.verify_stubbed_calls
        @tracer.flush

        span = @reports.dig(0, :span_records, 0)
        assert_equal "Faraday GET", span[:span_name]
        tags = [
          { Key: "component", Value: "faraday" },
          { Key: "http.domain", Value: "test.com" },
          { Key: "http.method", Value: "GET" },
          { Key: "http.status_code", Value: "202" },
          { Key: "http.url", Value: "http://user:password@test.com/foo" },
        ]
        assert_equal tags, span[:attributes].sort_by { |a| a[:Key] }
      end
    end
  end
end
