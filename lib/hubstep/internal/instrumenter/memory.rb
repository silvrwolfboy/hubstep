module HubStep
  module Internal
    module Instrumenter
      class Memory
        class Event
          attr_reader :name, :payload, :result

          def initialize(name, payload, result)
            @name, @payload, @result = name, payload, result
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
