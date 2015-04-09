# Congestion

A Redis rate limiter that provides both time-based limits and quantity-based limits.

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
  Redis.new(your_redis_config)
}
```

Global options can be set with:

```ruby
Congestion.default_options = {
  namespace: 'congestion' # The Redis key prefix (e.g. 'congestion:some_key')
  interval: 1,            # The timeframe to limit within in seconds
  max_in_interval: 1,     # The number of allowed requests within the interval
  min_delay: 0.0          # The minimum amount of time in seconds between requests
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
