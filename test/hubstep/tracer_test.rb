# frozen_string_literal: true

require_relative "../test_helper"

module HubStep
  class TracerTest < HubStep::TestCases
    def test_starts_out_disabled
      refute_predicate HubStep::Tracer.new, :enabled?
    end

    def test_with_enabled_can_enable_in_block
      tracer = HubStep::Tracer.new
      refute_predicate tracer, :enabled?

      enabled_in_block = nil
      tracer.with_enabled(true) do
        enabled_in_block = tracer.enabled?
      end

      assert enabled_in_block
      refute_predicate tracer, :enabled?
    end

    def test_with_enabled_can_disable_in_block
      tracer = HubStep::Tracer.new
      tracer.enabled = true
      assert_predicate tracer, :enabled?

      enabled_in_block = nil
      tracer.with_enabled(false) do
        enabled_in_block = tracer.enabled?
      end

      refute enabled_in_block
      assert_predicate tracer, :enabled?
    end

    def test_bottom_span_returns_inert_instance_when_not_tracing
      assert_equal HubStep::Tracer::InertSpan.instance, HubStep::Tracer.new.bottom_span
    end

    def test_bottom_span_returns_inert_instance_when_tracing_disabled
      tracer = HubStep::Tracer.new
      tracer.enabled = true
      span = nil
      tracer.span("foo") do
        tracer.with_enabled(false) do
          span = tracer.bottom_span
        end
      end
      assert_equal HubStep::Tracer::InertSpan.instance, span
    end

    def test_bottom_span_returns_bottom_span_when_tracing
      tracer = HubStep::Tracer.new
      tracer.enabled = true
      tracer.span("foo") do |foo|
        assert_equal foo, tracer.bottom_span
        tracer.span("bar") do |bar|
          assert_equal bar, tracer.bottom_span
        end
        assert_equal foo, tracer.bottom_span
      end
    end

    def test_span_yields_inert_instance_when_disabled
      HubStep::Tracer.new.span("foo") do |span|
        assert_equal HubStep::Tracer::InertSpan.instance, span
      end
    end

    def test_span_finishes_spans_unless_prohibited
      tracer = HubStep::Tracer.new
      tracer.enabled = true

      a = nil
      b = nil
      c = nil

      tracer.span("a") do |span|
        a = span
        tracer.span("b", finish: false) do |span2|
          b = span2
          assert_nil b.end_micros
        end

        tracer.span("c") do |span3|
          c = span3
          assert_nil c.end_micros
        end
        refute_nil c.end_micros
        assert_equal a.span_context.id, c.tags[:parent_span_guid]

        assert_nil a.end_micros
        assert_nil b.end_micros
      end

      refute_nil a.end_micros
      assert_nil b.end_micros

      b.finish
      refute_nil b.end_micros
    end

    def test_tracks_parent_child_relationships
      tracer = HubStep::Tracer.new
      tracer.enabled = true

      tracer.span("a") do |a|
        assert_nil a.tags[:parent_span_guid]
        tracer.span("b") do |b|
          assert_equal a.span_context.id, b.tags[:parent_span_guid]
          tracer.span("c") do |c|
            assert_equal b.span_context.id, c.tags[:parent_span_guid]
          end
        end
        tracer.span("d") do |d|
          assert_equal a.span_context.id, d.tags[:parent_span_guid]
        end
      end
    end

    class CustomError < StandardError; end

    def test_records_exceptions
      tracer = HubStep::Tracer.new
      tracer.enabled = true

      span = nil
      assert_raises CustomError do
        tracer.span("foo") do |s|
          span = s
          raise CustomError, "custom message"
        end
      end

      refute_nil span.end_micros
      assert span.tags["error"]
      assert_equal "HubStep::TracerTest::CustomError", span.tags["error.class"]
      assert_equal "custom message", span.tags["error.message"]
    end

    def test_configure_block_not_called_when_disabled
      tracer = HubStep::Tracer.new
      tracer.enabled = false
      calls = []
      tracer.span("foo") do |span|
        calls << "span"
        span.configure do
          calls << "configure"
        end
      end
      assert_equal %w[span], calls
    end

    def test_configure_block_called_when_enabled
      tracer = HubStep::Tracer.new
      tracer.enabled = true
      calls = []
      tracer.span("foo") do |span|
        calls << "span"
        span.configure do
          calls << "configure"
        end
      end
      assert_equal %w[span configure], calls
    end

    def test_can_pass_custom_transport
      reports = []
      callback = ->(report) { reports << report }
      transport = LightStep::Transport::Callback.new(callback: callback)
      tracer = HubStep::Tracer.new(transport: transport)
      tracer.enabled = true
      tracer.span("foo") { }
      tracer.flush
      refute_empty reports
    end

    def test_the_default_transport_is_correct_when_the_envs_are_set
      ENV.stubs(:[] => "foo")
      tracer = HubStep::Tracer.new
      transport = tracer.send(:default_transport)
      assert_equal HubStep::Transport::HTTPJSON, transport.class
    end

    def test_sets_tags_on_tracer
      reports = []
      callback = ->(report) { reports << report }
      transport = LightStep::Transport::Callback.new(callback: callback)
      tracer = HubStep::Tracer.new(transport: transport)
      tracer.enabled = true
      tracer.span("foo") { }
      tracer.flush

      attrs = reports.first.dig(:runtime, :attrs)
      custom_attrs = attrs.reject { |a| a[:Key].start_with?("lightstep.") }

      expected = [
        { Key: "hostname", Value: HubStep.hostname },
      ]

      assert_equal expected, custom_attrs.sort_by { |a| a[:Key] }
    end
  end
end
