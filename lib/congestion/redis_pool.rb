require 'redis'
require 'connection_pool'

module Congestion
  class RedisPool
    class << self
      attr_accessor :redis_config
      attr_accessor :pool_size
      attr_accessor :timeout
    end

    self.redis_config = { }
    self.pool_size = 5
    self.timeout = 5

    attr_accessor :pool

    def self.instance
      @instance ||= new
      @redis_pool ||= ->{ @instance.pool.with{ |redis| redis } }
    end

    private
    def initialize
      pool_config = { size: self.class.pool_size, timeout: self.class.timeout }

      self.pool = ConnectionPool.new(pool_config) do
        Redis.new self.class.redis_config
      end
    end
  end
end
