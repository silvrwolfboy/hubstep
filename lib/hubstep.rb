# frozen_string_literal: true

require "hubstep/tracer"
require "hubstep/internal/instrumenter/noop"
require "hubstep/version"

require "socket"

#:nodoc:
module HubStep
  # Internal: Get this machine's hostname.
  #
  # Returns a String.
  def self.hostname
    @hostname ||= Socket.gethostname.freeze
  end

  # Internal: Reads server data written during provisioning.
  #
  # Returns a Hash.
  def self.server_metadata
    return @server_metadata if defined?(@server_metadata)
    @server_metadata =
      begin
        JSON.parse(File.read("/etc/github/metadata.json")).freeze
      rescue
        {}.freeze
      end
  end

  # setter for instrumenter that defaults to the Noop instrumenter
  #
  # instrumenter - an object that responds to the ActiveSupport::Nofitications
  #                interface, when omitted the Noop instrumenter will be used
  #
  def self.instrumenter=(instrumenter)
    @instrumenter = instrumenter
  end

  # getter for the instrumenter ivar. When the ivar isn't set it will
  # default to the Noop instrumenter
  #
  # instrumenter - an object that responds to the ActiveSupport::Nofitications
  #                interface, when omitted the Noop instrumenter will be used
  #
  def self.instrumenter(instrumenter: HubStep::Internal::Instrumenter::Noop.new)
    @instrumenter ||= instrumenter
  end
end
