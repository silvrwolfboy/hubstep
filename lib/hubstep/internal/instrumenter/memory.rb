# frozen_string_literal: true

module HubStep
  module Internal
    module Instrumenter
      # A memory instrumenter to be used in to test instrumentation. This class records
      # each instrument call in a HubStep::Internal::Instrumenter::Memory::Event instance
      # and stores the instance in an events array.
      class Memory
        class Event # rubocop:disable Style/Documentation
          attr_reader :name, :payload, :result

          def initialize(name, payload, result)
            @name = name
            @payload = payload
            @result = result
          end
        end

        def initialize
          @events = []
        end

        attr_reader :events

        def instrument(name, payload = {})
          payload = payload.dup
          result = (yield payload if block_given?)
          @events << Event.new(name, payload, result)
          result
        end
      end
    end
  end
end
