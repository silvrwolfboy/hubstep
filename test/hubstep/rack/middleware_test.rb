# frozen_string_literal: true

require_relative "../../test_helper"
require "hubstep/rack/middleware"
require "rack/test"

module HubStep
  module Rack
    class MiddlewareTest < Minitest::Test
      include ::Rack::Test::Methods

      attr_reader :block

      def setup
        @block = ->(_env) { [200, {}, "<html>"] }
        @original_enabled = HubStep.tracing_enabled?
        HubStep.tracing_enabled = true
      end

      def teardown
        HubStep.tracing_enabled = @original_enabled
      end

      def tracer
        @tracer ||= Tracer.new
      end

      def test_requires_a_tracer
        app = ::Rack::Builder.new do
          use HubStep::Rack::Middleware
          run ->(_env) { [200, {}, "<html>"] }
        end
        assert_raises ArgumentError do
          app.to_app
        end
      end

      def test_wraps_request_in_span
        top_span = nil
        @block = lambda do |_env|
          top_span = tracer.top_span
          [302, {}, "<html>"]
        end

        get "/foo"

        expected = {
          "http.method" => "GET",
          "http.status_code" => "302",
          "http.url" => "http://example.org/foo",
          "span.kind" => "server",
        }

        assert_equal "request", top_span.operation_name
        assert_equal expected, top_span.tags.select { |key, _value| expected.key?(key) }
        refute_includes top_span.tags, "guid:github_request_id"
      end

      def test_records_request_id_if_present
        top_span = nil
        @block = lambda do |_env|
          top_span = tracer.top_span
          [302, {}, "<html>"]
        end

        get "/foo", {}, "HTTP_X_GITHUB_REQUEST_ID" => "1234abcd"

        assert_equal "1234abcd", top_span.tags["guid:github_request_id"]
      end

      def app
        test_instance = self
        @app ||= ::Rack::Builder.new do
          use HubStep::Rack::Middleware, test_instance.tracer
          run ->(env) { test_instance.block.call(env) }
        end
      end
    end
  end
end
