module HubStep
  module Internal
    module Instrumenter
      class Noop
        def instrument(_name, payload = {})
          yield payload if block_given?
        end
      end
    end
  end
end
