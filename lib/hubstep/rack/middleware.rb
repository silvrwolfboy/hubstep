# frozen_string_literal: true

require "rack"

module HubStep
  module Rack
    # Rack middleware for wrapping a request in a span.
    class Middleware
      # Create a Middleware
      #
      # tracer    - a HubStep::Tracer instance
      # enable_if - Proc that is passed the env for each request. If the Proc
      #             returns true, the tracer will be enabled for the duration
      #             of the request. If the Proc returns false, the tracer will
      #             be disabled for the duration of the request.
      def initialize(app, tracer, enable_if)
        @app = app
        @tracer = tracer
        @enable_if = enable_if
      end

      def call(env)
        @tracer.with_enabled(@enable_if.call(env)) do
          trace(env) do
            @app.call(env)
          end
        end
      end

      private

      def trace(env)
        @tracer.span("Rack #{env["REQUEST_METHOD"]}") do |span|
          span.configure do
            add_tags(span, ::Rack::Request.new(env))
          end

          result = yield

          span.set_tag("http.status_code", result[0].to_s)

          result
        end
      end

      def add_tags(span, request)
        tags(request).each do |key, value|
          span.set_tag(key, value)
        end
      end

      def tags(request)
        tags = {
          "component" => "rack",
          "span.kind" => "server",
          "http.url" => request.url,
          "http.method" => request.request_method,
        }
        id = request_id(request)
        if id
          tags["guid:github_request_id"] = id
        end

        tags.freeze
      end

      def request_id(request)
        request.env["HTTP_X_GITHUB_REQUEST_ID"]
      end
    end
  end
end
