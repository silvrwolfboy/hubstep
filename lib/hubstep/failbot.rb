# frozen_string_literal: true

require "English"
require "failbot"

module LightStep
  module Transport
    class HTTPJSON # rubocop:disable Style/Documentation
      # This reimplementation of LightStep::Transport::HTTPJSON#report reports
      # network errors and other exceptions to Failbot.
      module Failbot
        class HTTPError < StandardError; end

        # There's no way to call through to the normal implementation while getting
        # access to the request/response objects, so we just copy all the code
        # here.
        def report(report) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          p report if @verbose >= 3

          https = Net::HTTP.new(@host, @port)
          https.use_ssl = @encryption == ENCRYPTION_TLS
          req = Net::HTTP::Post.new("/api/v0/reports")
          req["LightStep-Access-Token"] = @access_token
          req["Content-Type"] = "application/json"
          req["Connection"] = "keep-alive"
          req.body = report.to_json

          ::Failbot.push(request_body: req.body)

          res = https.request(req)

          puts res.to_s, res.body if @verbose >= 3

          track_error(res)

          nil
        ensure
          ::Failbot.report!($ERROR_INFO) if $ERROR_INFO
          ::Failbot.pop
        end

        def track_error(res)
          return unless res.is_a?(Net::HTTPClientError) || res.is_a?(Net::HTTPServerError)
          exception = HTTPError.new("#{res.code} #{res.message}")
          exception.set_backtrace(caller)
          ::Failbot.report!(exception, response_body: res.body, response_uri: res.uri)
        end
      end

      prepend Failbot
    end
  end
end
