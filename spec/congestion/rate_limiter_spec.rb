require 'spec_helper'

describe Congestion::RateLimiter do
  include_context 'limiter helpers'

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

  describe '#time_since_last_request' do
    before(:each) do
      [4, 2, 3].each do |n|
        add_request seconds_ago n
      end
    end

    subject{ call_protected :time_since_last_request }
    it{ is_expected.to eql now - seconds_ago(2) }
  end

  describe '#time_since_first_request' do
    before(:each) do
      [3, 4, 2].each do |n|
        add_request seconds_ago n
      end
    end

    subject{ call_protected :time_since_first_request }
    it{ is_expected.to eql now - seconds_ago(4) }
  end

  describe '#expired_at' do
    subject{ call_protected :expired_at }
    it{ is_expected.to eql call_protected(:current_time) - 10_000 }
  end

  describe '#add_request' do
    before(:each){ limiter.options[:track_rejected] = false }
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

    before(:each) do
      [1, 2, 3, 10, 20].each do |n|
        add_request seconds_ago n
      end
    end

    its([0]){ is_expected.to eql 2 } # 2 old requests removed
    its([1]){ is_expected.to eql 3 } # 3 current requests
    its([2]){ is_expected.to eql [seconds_ago(3).to_s] } # first request
    its([3]){ is_expected.to eql [seconds_ago(1).to_s] } # last request

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

    context 'when tracking rejected' do
      before(:each){ limiter.options[:track_rejected] = true }

      its([4]){ is_expected.to be true }
      its([5]){ is_expected.to be true }

      it 'should track rejected requests' do
        clear_expired
        expect {
          subject
        }.to change {
          get_values.length
        }.by 1
      end
    end

    context 'when not tracking rejected' do
      before(:each){ limiter.options[:track_rejected] = false }

      its([4]){ is_expected.to be true }
      its([5]){ is_expected.to be nil }

      it 'should not track rejected requests' do
        clear_expired
        expect {
          subject
        }.to_not change {
          get_values.length
        }
      end
    end
  end

  describe '#total_requests' do
    subject{ limiter.total_requests }

    context 'when requests exist' do
      before(:each) do
        [1, 2, 3].each do |n|
          add_request seconds_ago n
        end
      end

      it{ is_expected.to eql 3 }
    end

    context 'when requests do not exist' do
      it{ is_expected.to eql 0 }
    end
  end

  describe '#first_request' do
    subject{ limiter.first_request }

    context 'when requests exist' do
      before(:each) do
        [1, 2, 3].each do |n|
          add_request seconds_ago n
        end
      end

      it{ is_expected.to eql seconds_ago(3) }
    end

    context 'when requests do not exist' do
      it{ is_expected.to be nil }
    end
  end

  describe '#last_request' do
    subject{ limiter.last_request }

    context 'when requests exist' do
      before(:each) do
        [1, 2, 3].each do |n|
          add_request seconds_ago n
        end
      end

      it{ is_expected.to eql seconds_ago(1) }
    end

    context 'when requests do not exist' do
      it{ is_expected.to be nil }
    end
  end

  describe '#too_many?' do
    subject{ limiter }
    before(:each){ limiter.options[:max_in_interval] = 1 }

    context 'when false' do
      before(:each){ add_request seconds_ago 1 }
      it{ is_expected.to_not be_too_many }
    end

    context 'when true' do
      before(:each){ 2.times{ |i| add_request seconds_ago i } }
      it{ is_expected.to be_too_many }
    end
  end

  describe '#too_frequent?' do
    subject{ limiter }
    before(:each){ limiter.options[:min_delay] = 2 }

    context 'when false' do
      before(:each){ add_request seconds_ago 2 }
      it{ is_expected.to_not be_too_frequent }
    end

    context 'when true' do
      before(:each){ 2.times{ |i| add_request seconds_ago i } }
      it{ is_expected.to be_too_frequent }
    end
  end

  describe '#rejected?' do
    subject{ limiter }

    context 'when allowed' do
      before(:each){ stub_limiter too_many?: false, too_frequent?: false }
      it{ is_expected.to_not be_rejected }
    end

    context 'when too many' do
      before(:each){ stub_limiter too_many?: true, too_frequent?: false }
      it{ is_expected.to be_rejected }
    end

    context 'when too frequent' do
      before(:each){ stub_limiter too_many?: false, too_frequent?: true }
      it{ is_expected.to be_rejected }
    end

    context 'when too many and too frequent' do
      before(:each){ stub_limiter too_many?: true, too_frequent?: true }
      it{ is_expected.to be_rejected }
    end
  end

  describe '#allowed?' do
    subject{ limiter }

    context 'when allowed' do
      before(:each){ stub_limiter rejected?: false }

      context 'when tracking rejected' do
        before(:each){ limiter.options[:track_rejected] = true }
        it{ is_expected.to be_allowed }

        it 'should not #add_request' do
          # because it's already added
          expect(limiter.redis).to_not receive :zadd
          limiter.allowed?
        end
      end

      context 'when not tracking rejected' do
        before(:each){ limiter.options[:track_rejected] = false }
        it{ is_expected.to be_allowed }

        it 'should #add_request' do
          # because it hasn't been added yet
          expect(limiter.redis).to receive :zadd
          limiter.allowed?
        end
      end
    end

    context 'when rejected' do
      before(:each) do
        stub_limiter rejected?: true
        limiter.options[:track_rejected] = false
      end

      it{ is_expected.to_not be_allowed }

      it 'should not #add_request' do
        # because it's already added
        expect(limiter.redis).to_not receive :zadd
        limiter.allowed?
      end
    end
  end
end
