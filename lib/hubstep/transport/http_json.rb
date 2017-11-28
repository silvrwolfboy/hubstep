# frozen_string_literal: true

require "English"
require "net/http"

unless LightStep::VERSION == '0.11.2'
  raise <<-MSG
    This custom transport needs to be reviewed for new LightStep versions.
    To review, compare this implementation with `LightStep::Transport::HTTPJSON#report`
    method and port any changes that seem necessary.
  MSG
end

module HubStep
  module Transport
    # HTTPJSON is our customized transport which add some additional
    # instrumentation and performance improvements.
    #
    # Callback Notes: To provide some observability into this transport's
    # operation, we allow a callback `on_report_callback` to be provided. This
    # callback will be called with the signature (report, result, duration_ms)
    # where result can be either the http response or an exception. This
    # callback will be delivered while maintaining this transports mutex which
    # should provide some measure of thread-safety for the caller.
    class HTTPJSON < LightStep::Transport::Base
      ENCRYPTION_TLS = 'tls'
      ENCRYPTION_NONE = 'none'

      # Provide access to the underlying Net::HTTP object so we can do fun
      # stuff like verify keep-alive is working.
      attr_reader :http

      # Initialize the transport
      # @param host [String] host of the domain to the endpoind to push data
      # @param port [Numeric] port on which to connect
      # @param encryption [ENCRYPTION_TLS, ENCRYPTION_NONE] kind of encryption to use
      # @param access_token [String] access token for LightStep server
      # @param on_report_callback [method] Called after reporting has completed
      # @return [HTTPJSON]
      def initialize(host:, port:, encryption: ENCRYPTION_TLS, access_token:, on_report_callback: nil)
        @on_report_callback = on_report_callback

        raise Tracer::ConfigurationError, "host must be specified" if host.nil? || host.empty?
        raise Tracer::ConfigurationError, "port must be specified" if port.nil?
        raise Tracer::ConfigurationError, "access_token must be a string" unless String === access_token
        raise Tracer::ConfigurationError, "access_token cannot be blank"  if access_token.empty?

        @access_token = access_token

        # This mutex protects the use of our Net::HTTP instance which we
        # maintain as a long lived connection. While a Lightstep::Transport is
        # typically called only from within the reporting thread, there are
        # some situations where this can be bypassed (directly calling `flush`
        # for example)
        @mutex = Mutex.new

        @http = Net::HTTP.new(host, port)
        @http.use_ssl = encryption == ENCRYPTION_TLS
        @http.keep_alive_timeout = 5
      end

      def report(report)
        start = Time.now

        req = request report

        @mutex.synchronize do
          begin
            res = @http.request(req)
          rescue => e
            res = e
          ensure
            @on_report_callback&.call(report, res, start)
          end
        end

        nil
      end

      private

      def request(report)
        req = Net::HTTP::Post.new('/api/v0/reports')
        req['LightStep-Access-Token'] = @access_token
        req['Content-Type'] = 'application/json'
        req['Connection'] = 'keep-alive'

        req.body = report.to_json
        req
      end
    end
  end
end
