require 'spec_helper'

RSpec.shared_context 'limiter helpers' do
  before(:each){ limiter.redis.flushall }

  let(:limiter) do
    Congestion.request('key', {
      namespace: 'test',
      interval: 10,
      min_delay: 5
    })
  end

  let(:now){ call_protected :current_time }

  def seconds_ago(n)
    now - n * 1_000
  end

  def add_request(time)
    limiter.redis.zadd limiter.key, time, time
  end

  def clear_expired
    expired_at = call_protected :expired_at
    limiter.redis.zremrangebyscore limiter.key, 0, expired_at
  end

  def get_values
    limiter.redis.zrange(limiter.key, 0, -1).map &:to_i
  end

  def call_protected(*args)
    limiter.send *args
  end
end
