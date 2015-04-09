require 'spec_helper'

describe Congestion::RateLimiter do
  let(:limiter) do
    Congestion.request('key', {
      namespace: 'test',
      interval: 10,
      min_delay: 5
    })
  end

  def call_protected(*args)
    limiter.send *args
  end

  describe '#initialize' do
    subject{ limiter }
    its(:redis){ is_expected.to be_a Redis }
    its(:key){ is_expected.to eql 'test:key' }

    describe '#options' do
      subject{ limiter.options }
      its([:namespace]){ is_expected.to eql 'test' }
      its([:interval]){ is_expected.to eql 10_000 }
      its([:max_in_interval]){ is_expected.to eql 1 }
      its([:min_delay]){ is_expected.to eql 5_000 }
    end
  end

  describe '#current_time' do
    subject{ call_protected :current_time }
    it{ is_expected.to be_within(20).of Time.now.utc.to_f * 1_000 }
    its(:object_id){ is_expected.to eql call_protected(:current_time).object_id }
  end

  describe '#expired_at' do
    subject{ call_protected :expired_at }
    it{ is_expected.to eql call_protected(:current_time) - 10_000 }
  end

  describe '#add_request' do
    subject{ call_protected :add_request }
    it{ is_expected.to be true }

    it 'should ZADD the request' do
      time = call_protected :current_time
      expect(limiter.redis).to receive(:zadd)
        .with limiter.key, time, time
      subject
    end
  end

  describe '#get_requests' do
    subject{ call_protected :get_requests }
    let(:now){ call_protected :current_time }

    def seconds_ago(n)
      now - n * 1_000
    end

    def add_request(time)
      limiter.redis.zadd limiter.key, time, time
    end

    def get_values
      limiter.redis.zrange(limiter.key, 0, -1).map &:to_i
    end

    before(:each) do
      limiter.redis.flushall
      [1, 2, 3, 10, 20].each do |n|
        add_request seconds_ago n
      end
    end

    its([0]){ is_expected.to eql 2 } # 2 old requests removed
    its([1]){ is_expected.to eql 3 } # 3 current requests
    its([2]){ is_expected.to eql [seconds_ago(3).to_s] } # first request
    its([3]){ is_expected.to eql [seconds_ago(1).to_s] } # last request
    its([4]){ is_expected.to be true }

    it 'should clear old requests' do
      subject
      count = limiter.redis.zcard limiter.key
      expect(count).to eql 3
    end

    it 'should set the ttl on the key' do
      subject
      ttl = limiter.redis.ttl limiter.key
      expect(ttl).to be_within(1).of 10 # the interval
    end
  end
end
