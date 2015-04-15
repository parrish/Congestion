# Congestion

[![Build Status](https://travis-ci.org/parrish/Congestion.svg?branch=master)](https://travis-ci.org/parrish/Congestion)
[![Test Coverage](https://codeclimate.com/github/parrish/Congestion/badges/coverage.svg)](https://codeclimate.com/github/parrish/Congestion)
[![Code Climate](https://codeclimate.com/github/parrish/Congestion/badges/gpa.svg)](https://codeclimate.com/github/parrish/Congestion)
[![Gem Version](https://badge.fury.io/rb/congestion.svg)](http://badge.fury.io/rb/congestion)

A Redis rate limiter that provides both time-based limits and quantity-based limits based on [classdojo/rolling-rate-limiter](https://github.com/classdojo/rolling-rate-limiter).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'congestion'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install congestion

## Usage

### Making requests

```ruby
limiter = Congestion.request 'some_key'
```

Where `'some_key'` is an identifier for this request.

A common use case might be to set rate limits per user with something like `"#{ user.id }_some_key"`.

`Congestion.request` returns an an instance that provides information about the request:

```ruby
limiter.allowed?      # => true if the request is permitted
limiter.rejected?     # => true if the request is not permitted
limiter.too_many?     # => true if there are too many requests in the interval
limiter.too_frequent? # => true if the requests are arriving too quickly
limiter.backoff       # => the number of seconds before a request will be permitted
```

### Configuration

A proc provides a Redis connection:

```ruby
Congestion.redis = ->{
  Redis.new url: 'redis://:password@host:port/db'
}
```

To pool, your Redis connections:

```ruby
require 'congestion/redis_pool'

Congestion::RedisPool.redis_config = {
  url: 'redis://:password@host:port/db'
}

Congestion::RedisPool.pool_size = 10  # number of connections to use
Congestion::RedisPool.timeout = 10    # seconds before timing out an operation

Congestion.redis = Congestion::RedisPool.instance
```

Global options can be set with:

```ruby
Congestion.default_options = {
  namespace: 'congestion' # The Redis key prefix (e.g. 'congestion:some_key')
  interval: 1,            # The timeframe to limit within in seconds
  max_in_interval: 1,     # The number of allowed requests within the interval
  min_delay: 0.0,         # The minimum amount of time in seconds between requests
  track_rejected: true    # True if rejected request count towards the limit
}
```

Per-request options can be set as well:

```ruby
Congestion.request 'some_key', interval: 60, min_delay: 1
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To run the specs, run `bundle exec rake`.

## Contributing

1. Fork it ( https://github.com/parrish/congestion/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
