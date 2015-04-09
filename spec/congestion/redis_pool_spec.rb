require 'spec_helper'
require 'congestion/redis_pool'

describe Congestion::RedisPool do
  describe '.redis_config' do
    subject{ Congestion::RedisPool.redis_config }
    it{ is_expected.to eql Hash.new }
  end

  describe '.pool_size' do
    subject{ Congestion::RedisPool.pool_size }
    it{ is_expected.to eql 5 }
  end

  describe '.timeout' do
    subject{ Congestion::RedisPool.timeout }
    it{ is_expected.to eql 5 }
  end

  describe '.instance' do
    subject{ Congestion::RedisPool.instance }
    before(:each) do
      Congestion::RedisPool.instance_variable_set :@instance, nil
      Congestion::RedisPool.instance_variable_set :@redis_pool, nil
    end

    it{ is_expected.to be_a Proc }
    its(:call){ is_expected.to be_a Redis }

    it 'should initialize a connection pool' do
      expect(ConnectionPool).to receive(:new)
        .with(size: 5, timeout: 5)
      subject
    end

    it 'should initialize Redis' do
      expect(Redis).to receive(:new).with({ }).and_call_original
      subject.call
    end

    it 'should return a singleton' do
      first_call = Congestion::RedisPool.instance.object_id
      second_call = Congestion::RedisPool.instance.object_id
      expect(first_call).to eql second_call
    end
  end
end
