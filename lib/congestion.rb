require 'redis'
require 'congestion/version'
require 'congestion/rate_limiter'

module Congestion
  class << self
    attr_accessor :default_options
    attr_accessor :redis
  end

  self.default_options = {
    namespace: 'congestion', # Redis key namespace
    interval: 1,             # 1 second
    max_in_interval: 1,      # 1 / second
    min_delay: 0             # none
  }

  self.redis = ->{
    Redis.new
  }

  def self.request(key, opts = { })
    RateLimiter.new redis.call, key, default_options.merge(opts)
  end
end
