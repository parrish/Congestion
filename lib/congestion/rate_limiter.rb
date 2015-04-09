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

    def total_requests
      get_requests[1]
    end

    def first_request
      first = get_requests[2].first
      first ? first.to_i : nil
    end

    def last_request
      last = get_requests[3].first
      last ? last.to_i : nil
    end

    protected

    def current_time
      @current_time ||= (Time.now.utc.to_f * 1_000).round
    end

    def expired_at
      current_time - options[:interval]
    end

    def add_request
      unless options[:track_rejected]
        redis.zadd key, current_time, current_time
      end
    end

    def get_requests
      @requests ||= redis.multi do |t|
        t.zremrangebyscore key, 0, expired_at   # [0] - clear old requests
        t.zcount key, '-inf', '+inf'            # [1] - number of requests
        t.zrange key, 0, 0                      # [2] - first request
        t.zrange key, -1, -1                    # [3] - last request
        t.pexpire key, options[:interval]       # [4] - expire request key

        # [5] - Add the request if tracking rejected
        t.zadd(key, current_time, current_time) if options[:track_rejected]
      end
    end
  end
end
