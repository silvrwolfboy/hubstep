# frozen_string_literal: true
require "thread"
require "rack"
require "rack/server"
require_relative "../test_helper"

class App
  attr_reader :mutex, :calls

  def initialize
    @mutex = Mutex.new
    @calls = 0
  end

  def call(_)
    # Note we are not unlocking...
    @calls += 1

    @mutex.lock
    [200, {}, ["application"]]
  end
end

module HubStep
  class HTTPJSONTest < HubStep::TestCases
    def default_args
      {
        host: "foo",
        port: 100,
        encryption: "bar",
        access_token: "baz",
      }
    end

    def test_callback_successful_report
      cb = mock
      cb.expects(:call).with do |report, result, duration_ms|
        assert_equal({}, report)
        assert_equal("200", result.code)
        assert duration_ms > 0.0
      end

      transport = HubStep::Transport::HTTPJSON.new(default_args.merge(on_report_callback: cb))

      stub_request(:post, "http://foo:100/api/v0/reports")
        .to_return(status: 200, body: "", headers: {})

      transport.report({})
    end

    def test_callback_when_an_error_when_reporting
      error = StandardError.new
      Net::HTTP.any_instance.expects(:request).raises(error)

      cb = mock
      cb.expects(:call).with do |report, result, duration_ms|
        assert_equal({}, report)
        assert_equal(error, result)
        assert duration_ms.positive?
      end

      transport = HubStep::Transport::HTTPJSON.new(default_args.merge(on_report_callback: cb))

      stub_request(:post, "http://foo:100/api/v0/reports")
        .to_return(status: 200, body: "", headers: {})

      transport.report({})
    end

    def test_is_thread_safe
      app = App.new
      stub_request(:post, "http://foo:100/api/v0/reports").to_rack(app)

      cb = mock
      cb.expects(:call).twice.with do |report, _, _|
        assert report[:hello]
        assert !app.mutex.try_lock
      end

      t = HubStep::Transport::HTTPJSON.new default_args.merge(on_report_callback: cb)

      # This lock will hold the requests so they don't complete
      app.mutex.lock

      report_a = Thread.new do
        t.report hello: true
      end

      report_b = Thread.new do
        t.report hello: true
      end

      sleep 0.250

      # Only one thread will have been able to call
      assert_equal 1, app.calls

      # Now our request can complete, and the second thread will be allowed
      # through as well.
      app.mutex.unlock

      sleep 0.250

      assert_equal 2, app.calls

      report_a.terminate
      report_b.terminate
    end
  end
end
