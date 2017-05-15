# frozen_string_literal: true

require "English"
require "net/http"
require "lightstep/transport/base"

module HubStep
  module Transport
    # HTTPJSON is a transport that sends reports via HTTP in JSON format.
    # It is thread-safe, however it is *not* fork-safe. When forking, all items
    # in the queue will be copied and sent in duplicate.
    #
    # When forking, you should first `disable` the tracer, then `enable` it from
    # within the fork (and in the parent post-fork). See
    # `examples/fork_children/main.rb` for an example.
    class HTTPJSON < LightStep::Transport::Base
      # Initialize the transport
      # @param host [String] host of the domain to the endpoind to push data
      # @param port [Numeric] port on which to connect
      # @param verbose [Numeric] verbosity level. Right now 0-3 are supported
      # @param encryption [ENCRYPTION_TLS, ENCRYPTION_NONE] kind of encryption to use
      # @param access_token [String] access token for LightStep server
      # @param statsd [#increment] a statsd client
      # @return [HTTPJSON]
      def initialize(host:, port:, verbose:, encryption:, access_token:, statsd:)
        @host = host
        @port = port
        @verbose = verbose
        @encryption = encryption
        @increment = statsd ? statsd.public_method(:increment) : Proc.new {}

        raise LightStep::Tracer::ConfigurationError, "access_token must be a string" unless String === access_token
        raise LightStep::Tracer::ConfigurationError, "access_token cannot be blank"  if access_token.empty?
        @access_token = access_token
      end

      # Queue a report for sending
      def report(report)
        p report if @verbose >= 3

        https = Net::HTTP.new(@host, @port)
        https.use_ssl = @encryption == ENCRYPTION_TLS
        req = Net::HTTP::Post.new('/api/v0/reports')
        req['LightStep-Access-Token'] = @access_token
        req['Content-Type'] = 'application/json'
        req['Connection'] = 'keep-alive'
        req.body = report.to_json
        res = https.request(req)

        puts res.to_s, res.body if @verbose >= 3

        track_error(res)

        nil
      rescue
        @increment.call("hubstep.error")
      end

      private

      def track_error(res)
        return unless res.is_a?(Net::HTTPClientError) || res.is_a?(Net::HTTPServerError)
        @increment.call("hubstep.http_error") if res.is_a?(Net::HTTPClientError)
      end
    end
  end
end
