require 'spec_helper'

RSpec.shared_context 'limiter helpers' do
  before(:each){ limiter.redis.flushall }

  let(:limiter) do
    Congestion.request('key', {
      namespace: 'test',
      interval: 10,
      min_delay: 5
    }).tap do |congestion|
      # Clear cached request for easier spies
      congestion.instance_variable_set :@requests, nil
    end
  end

  let(:redis){ Redis.new $REDIS_CONFIG }
  let(:now){ call_protected :current_time }

  def stub_limiter(stubs)
    stubs.each_pair do |attr, return_value|
      allow(limiter).to receive(attr).and_return return_value
    end
  end

  def seconds_ago(n)
    now - n * 1_000
  end

  def add_request(time)
    redis.zadd limiter.key, time, time
  end

  def clear_expired
    expired_at = call_protected :expired_at
    redis.zremrangebyscore limiter.key, 0, expired_at
  end

  def get_values
    redis.zrange(limiter.key, 0, -1).map &:to_i
  end

  def call_protected(*args)
    limiter.send *args
  end
end
