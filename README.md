# HubStep

HubStep provides standard tracing via [LightStep][] for GitHub-style Ruby apps.

[LightStep]: http://lightstep.com/

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hubstep'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hubstep

## Usage

The core of HubStep is [`HubStep::Tracer`][tracer]. This wraps
`LightStep::Tracer` and provides a block-based API for tracing, and the ability
to enable/disable tracing at runtime. Typical usage looks something like:

```ruby
require "hubstep"

module MyApp
  def self.tracer
    @tracer ||= HubStep::Tracer.new(tags: { "environment" => MyApp.environment })
  end

  class Fribble
    def frob
      MyApp.tracer.span("fribble.frob") do |span|
        # real work goes here
        span.set_tag("result", "success")
      end
    end
  end
end
```

[tracer]: /lib/hubstep/tracer.rb

In addition to explicit tracing like in the above example, HubStep provides
automatic instrumentation for various libraries.

### ActiveSupport::Notifications

[`HubStep::Instrumenter`][instrumenter] wraps `ActiveSupport::Notifications`
and automatically creates spans for any blocks passed to `#instrument`:

```ruby
require "hubstep/instrumenter"

module MyApp
  def self.instrumenter
    @instrumenter ||= HubStep::Instrumenter.new(self.tracer, ActiveSupport::Notifications)
  end

  class Fribble
    def frob
      MyApp.instrumenter.instrument("fribble.frob") do |payload, span|
        # real work goes here
        span.set_tag("result", "success")
      end
    end
  end
end
```

[instrumenter]: /lib/hubstep/instrumenter.rb

### Faraday

[`HubStep::Faraday::Middlware`][fm] is a [Faraday][] middleware that wraps each
request in a span.

```ruby
require "hubstep/faraday/middleware"

module MyApp
  def self.faraday
    @faraday ||= Faraday.new do |b|
                   b.request(:hubstep)
                   b.adapter(:typhoeus)
                 end
  end
end
```

[fm]: /lib/hubstep/faraday/middleware.rb
[Faraday]: https://github.com/lostisland/faraday

### Rack/Sinatra

[`HubStep::Rack::Middleware`][rm] is a [Rack][]/[Sinatra][] middleware that wraps
each request in a span. This middleware also enables or disables tracing for
the duration of a request based on the return value of the proc passed to it.

```ruby
# config.ru

require "hubstep/rack/middleware"

use HubStep::Rack::Middleware, MyApp.tracer, ->(env) { MyApp.tracing_enabled?(env) }
```

[rm]: /lib/hubstep/rack/middleware.rb
[Rack]: http://rack.github.io/
[Sinatra]: http://www.sinatrarb.com/

## Development

After checking out the repo, run `script/bootstrap` to install dependencies. Then, run `rake test` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/hubstep. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
