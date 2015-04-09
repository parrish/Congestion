require 'spec_helper'

describe Congestion::RateLimiter do
  let(:limiter) do
    Congestion.request('key', {
      namespace: 'test',
      interval: 10,
      min_delay: 5
    })
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
end
