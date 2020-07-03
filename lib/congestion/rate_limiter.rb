module Congestion
  class RateLimiter
    attr_accessor :redis, :key, :options

    def initialize(redis, key, opts = { })
      self.redis = redis
      self.key = "#{ opts[:namespace] }:#{ key }"
      self.options = opts
      self.options[:interval] *= 1_000
      self.options[:min_delay] *= 1_000
      allowed?
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

    def allowed?
      add_request unless rejected?
      !rejected?
    end

    def rejected?
      too_many? || too_frequent?
    end

    def too_many?
      total_requests > options[:max_in_interval]
    end

    def too_frequent?
      last_request && time_since_last_request < options[:min_delay]
    end

    def backoff
      if too_many? && too_frequent?
        [quantity_backoff, frequency_backoff].max
      elsif too_many?
        quantity_backoff
      elsif too_frequent?
        frequency_backoff
      else
        0
      end
    end

    protected

    def current_time
      @current_time ||= (Time.now.utc.to_f * 1_000).round
    end

    def time_since_last_request
      current_time - last_request
    end

    def time_since_first_request
      current_time - first_request
    end

    def expired_at
      current_time - options[:interval]
    end

    def quantity_backoff
      millis = options[:interval] - time_since_first_request
      (millis / 1_000.0).ceil
    end

    def frequency_backoff
      millis = options[:min_delay] - time_since_last_request
      (millis / 1_000.0).ceil
    end

    def add_request
      unless options[:track_rejected]
        add_request = redis.multi do |t|
          t.zadd key, current_time, current_time # [0] - key added
          t.ttl key                              # [1] - key ttl
        end
        # TTL is -1 if not set, https://redis.io/commands/ttl
        if add_request[1] == -1
          # ensure we set the expire TTL on the request key
          # using the raw interval here after the 'get_requests' limit check
          # should be close enough to the actual interval folks desire
          redis.pexpire key, options[:interval]
        end
      end
    end

    def get_requests
      @requests ||= redis.multi do |t|
        t.zremrangebyscore key, 0, expired_at     # [0] - clear old requests
        t.zcount key, '-inf', '+inf'              # [1] - number of requests
        t.zrange key, 0, 0                        # [2] - first request
        t.zrange key, -1, -1                      # [3] - last request
        if options[:track_rejected]
          t.zadd(key, current_time, current_time) # [4] - Add the request if tracking rejected
        end
        # ensure the TTL is set after we've added the key if tracking rejected
        t.pexpire key, options[:interval]         # [5] - expire request key
      end
    end
  end
end
