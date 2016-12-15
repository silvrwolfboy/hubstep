# frozen_string_literal: true

require "hubstep/tracer"
require "hubstep/version"

require "socket"

#:nodoc:
module HubStep
  def self.tracing_enabled=(value)
    @tracing_enabled = value
  end

  def self.tracing_enabled?
    !!@tracing_enabled
  end

  def self.hostname
    @hostname ||= Socket.gethostname.freeze
  end

  # Returns a global Tracer instance.
  def self.tracer
    @tracer ||= Tracer.new
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
end
