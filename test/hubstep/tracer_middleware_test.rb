# frozen_string_literal: true

require_relative "../test_helper"
require "hubstep/tracer_middleware"
require "rack/test"

module HubStep
  class TracerMiddlewareTest < Minitest::Test
    include Rack::Test::Methods

    attr_reader :block

    def setup
      @block = ->(_env) { [200, {}, "<html>"] }
      @original_enabled = HubStep.tracing_enabled?
      HubStep.tracing_enabled = true
    end

    def teardown
      HubStep.tracing_enabled = @original_enabled
    end

    def test_wraps_request_in_span
      top_span = nil
      @block = lambda { |_env|
        top_span = HubStep.tracer.top_span
        [302, {}, "<html>"]
      }

      get "/foo"

      assert_equal "request", top_span.operation_name
      assert_equal "GET", top_span.tags["http.method"]
      assert_equal "302", top_span.tags["http.status_code"]
      assert_equal "http://example.org/foo", top_span.tags["http.url"]
      assert_equal "server", top_span.tags["span.kind"]
      refute_includes top_span.tags, "guid:github_request_id"
    end

    def test_records_request_id_if_present
      top_span = nil
      @block = lambda { |_env|
        top_span = HubStep.tracer.top_span
        [302, {}, "<html>"]
      }

      get "/foo", {}, { "HTTP_X_GITHUB_REQUEST_ID" => "1234abcd" }

      assert_equal "1234abcd", top_span.tags["guid:github_request_id"]
    end

    def app
      test_instance = self
      @app ||= Rack::Builder.new do
        use HubStep::TracerMiddleware
        run lambda { |env|
          test_instance.block.call(env)
        }
      end
    end
  end
end
