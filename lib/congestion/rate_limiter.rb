module Congestion
  class RateLimiter
    attr_accessor :redis, :key, :options

    def initialize(redis, key, opts = { })
      self.redis = redis
      self.key = "#{ opts[:namespace] }:#{ key }"
      self.options = opts
      self.options[:interval] *= 1_000
      self.options[:min_delay] *= 1_000
    end
  end
end
