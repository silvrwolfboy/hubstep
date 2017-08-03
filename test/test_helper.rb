# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "hubstep"

require "pry-byebug"
require "minitest/autorun"
require "webmock/minitest"
require "mocha/mini_test"

require "failbot"
ENV["FAILBOT_BACKEND"] ||= "memory"
Failbot.setup(ENV, app: "hubstep-test")
