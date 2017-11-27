# frozen_string_literal: true

require_relative "../../test_helper"
require "hubstep/rack/middleware"
require "rack/test"

module HubStep
  module Rack
    class MiddlewareTest < HubStep::TestCases
      include ::Rack::Test::Methods

      attr_reader :request_proc, :enabled_proc

      def setup
        @request_proc = ->(_env) { [200, {}, "<html>"] }
        @enabled_proc = ->(_env) { true }
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

      def test_requires_an_enabled_proc
        app = ::Rack::Builder.new do
          use HubStep::Rack::Middleware, tracer: HubStep::Tracer.new
          run ->(_env) { [200, {}, "<html>"] }
        end
        assert_raises ArgumentError do
          app.to_app
        end
      end

      def test_passes_env_to_enabled_proc
        passed_env = nil
        @enabled_proc = lambda do |env|
          passed_env = env
          true
        end

        get "/foo"

        assert_kind_of Hash, passed_env
        assert_equal "/foo", passed_env["PATH_INFO"]
      end

      def test_enables_tracing_during_request_if_specified
        tracer.enabled = false
        enabled_in_request = nil
        @request_proc = lambda do |_env|
          enabled_in_request = tracer.enabled?
          [200, {}, "<html>"]
        end
        @enabled_proc = ->(_env) { true }

        get "/foo"

        assert enabled_in_request
        refute tracer.enabled?
      end

      def test_disables_tracing_during_request_if_specified
        tracer.enabled = true
        enabled_in_request = nil
        @request_proc = lambda do |_env|
          enabled_in_request = tracer.enabled?
          [200, {}, "<html>"]
        end
        @enabled_proc = ->(_env) { false }

        get "/foo"

        assert_equal false, enabled_in_request
        assert tracer.enabled?
      end

      def test_records_request_method
        span = nil
        @request_proc = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [302, {}, "<html>"]
        end

        get "/foo"
        assert_equal "Rack GET", span.operation_name
        assert_equal "GET", span.tags["http.method"]
        post "/bar"
        assert_equal "Rack POST", span.operation_name
        assert_equal "POST", span.tags["http.method"]
      end

      def test_records_status_code
        span = nil
        @request_proc = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [@status_code, {}, "<html>"]
        end

        @status_code = 200
        get "/foo"
        assert_equal "200", span.tags["http.status_code"]
        refute span.tags["error"]

        @status_code = 404
        get "/foo"
        assert_equal "404", span.tags["http.status_code"]
        refute span.tags["error"]

        @status_code = 500
        get "/foo"
        assert_equal "500", span.tags["http.status_code"]
        assert span.tags["error"]
      end

      def test_wraps_request_in_span
        span = nil
        @request_proc = lambda do |_env|
          span = tracer.bottom_span
          [302, {}, "<html>"]
        end

        get "/foo"

        assert_equal "rack", span.tags["component"]
        assert_equal "server", span.tags["span.kind"]
      end

      def test_omits_urls_by_default
        span = nil
        @request_proc = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [302, {}, "<html>"]
        end

        test_instance = self
        @app = ::Rack::Builder.new do
          use HubStep::Rack::Middleware,
              tracer: test_instance.tracer,
              enable_if: test_instance.enabled_proc
          run test_instance.request_proc
        end

        get "/foo"

        refute_includes span.tags, "http.url"
      end

      def test_includes_urls_if_specified
        span = nil
        @request_proc = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [302, {}, "<html>"]
        end

        test_instance = self
        @app = ::Rack::Builder.new do
          use HubStep::Rack::Middleware,
              tracer: test_instance.tracer,
              enable_if: test_instance.enabled_proc,
              include_urls: true
          run test_instance.request_proc
        end

        get "/foo"

        assert_equal "http://example.org/foo", span.tags["http.url"]
      end

      def test_records_request_id_if_present
        span = nil
        @request_proc = lambda do |_env|
          span = tracer.bottom_span
          [302, {}, "<html>"]
        end

        get "/foo", {}, "HTTP_X_GITHUB_REQUEST_ID" => "1234abcd"

        assert_equal "1234abcd", span.tags["guid:github_request_id"]
      end

      def test_stores_span_on_env
        span = nil
        @request_proc = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [302, {}, "<html>"]
        end

        get "/foo"

        assert_equal "Rack GET", span.operation_name
      end

      def test_get_span_returns_inert_span_when_using_middleware
        span = nil
        @app = lambda do |env|
          span = HubStep::Rack::Middleware.get_span(env)
          [302, {}, "<html>"]
        end

        get "/foo"

        assert_kind_of HubStep::Tracer::InertSpan, span
      end

      def app
        test_instance = self
        @app ||= ::Rack::Builder.new do
          use HubStep::Rack::Middleware,
              tracer: test_instance.tracer,
              enable_if: test_instance.enabled_proc
          run test_instance.request_proc
        end
      end
    end
  end
end
