# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hubstep/version"

Gem::Specification.new do |spec|
  spec.name          = "hubstep"
  spec.version       = HubStep::VERSION
  spec.authors       = ["GitHub"]
  spec.email         = ["engineering@github.com"]

  spec.summary       = "Standard LightStep tracing of GitHub Ruby apps"
  spec.description   = "Makes it easy to trace Sinatra and Ruby apps that use GitHub conventions."
  spec.homepage      = "https://github.com/github/hubstep"
  spec.license       = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # We must pin to exact versions due to monkey patching
  spec.add_dependency "lightstep", "0.11.2"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 0.46.0"
  spec.add_development_dependency "rack-test", "~> 0.6"
  spec.add_development_dependency "activesupport", "~> 4.0"
  spec.add_development_dependency "faraday", "~> 0.10"
  spec.add_development_dependency "failbot", "~> 2.0.0"
  spec.add_development_dependency "webmock", "~> 2.3.1"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "mocha", "~> 1.2.1"
end
