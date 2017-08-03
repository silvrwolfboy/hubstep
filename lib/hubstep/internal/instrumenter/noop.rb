# frozen_string_literal: true

module HubStep
  module Internal
    module Instrumenter
      # A noop instrumenter that fulfills the interface for ActiveSupport::Notifications
      # but does nothing. This is the default instrumenter when the client does not pass
      # one in
      class Noop
        def instrument(_name, payload = {})
          yield payload if block_given?
        end
      end
    end
  end
end
