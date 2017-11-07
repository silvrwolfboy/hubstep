# frozen_string_literal: true

require "English"
require "net/http"

unless LightStep::VERSION == '0.11.2'
  raise <<-MSG
    This monkey patch needs to be reviewed for LightStep versions other than 0.10.9.
    To review, diff the changes between the `LightStep::Transport::HTTPJSON#report`
    method and the `HubStep::Transport::HTTPJSON#report` method below and port any
    changes that seem necessary.
  MSG
end

module HubStep
  module Transport
    # HTTPJSON is a transport that sends reports via HTTP in JSON format.
    # It is thread-safe, however it is *not* fork-safe. When forking, all items
    # in the queue will be copied and sent in duplicate.
    #
    # When forking, you should first `disable` the tracer, then `enable` it from
    # within the fork (and in the parent post-fork). See
    # `examples/fork_children/main.rb` for an example.
    class HTTPJSON < LightStep::Transport::HTTPJSON
      # Queue a report for sending
      def report(report) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        p report if @verbose >= 3

        HubStep.instrumenter.instrument('lightstep.transport.report', {}) do |payload|
          https = Net::HTTP.new(@host, @port)
          https.use_ssl = @encryption == ENCRYPTION_TLS
          req = Net::HTTP::Post.new('/api/v0/reports')
          req['LightStep-Access-Token'] = @access_token
          req['Content-Type'] = 'application/json'
          req['Connection'] = 'keep-alive'
          req.body = report.to_json
          res = https.request(req)

          payload[:request_body] = req.body

          puts res.to_s, res.body if @verbose >= 3

          payload[:response] = res
        end

        nil
      rescue => e
        HubStep.instrumenter.instrument('lightstep.transport.error', error: e)
      end
    end
  end
end
