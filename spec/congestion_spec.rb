require 'spec_helper'

describe Congestion do
  describe '.redis' do
    subject{ Congestion.redis }
    it{ is_expected.to be_a Proc }
    its(:call){ is_expected.to be_a Redis }
  end

  describe '.default_options' do
    subject{ Congestion.default_options }
    its([:namespace]){ is_expected.to eql 'congestion' }
    its([:interval]){ is_expected.to eql 1 }
    its([:max_in_interval]){ is_expected.to eql 1 }
    its([:min_delay]){ is_expected.to eql 0 }
  end

  describe '.request' do
    it 'should return a new instance' do
      expect(Congestion.request('foo')).to be_a Congestion::RateLimiter
    end

    context 'without options' do
      it 'should initialize with defaults' do
        expect(Congestion::RateLimiter).to receive(:new)
          .with an_instance_of(Redis),
            'foo',
            Congestion.default_options

        Congestion.request 'foo'
      end
    end

    context 'with options' do
      it 'should initialize with options' do
        expect(Congestion::RateLimiter).to receive(:new)
          .with an_instance_of(Redis),
            'foo',
            Congestion.default_options.merge(interval: 99)

        Congestion.request 'foo', interval: 99
      end
    end
  end
end
