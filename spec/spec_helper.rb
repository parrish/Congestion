require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'rspec/its'
require 'timecop'
require 'congestion'
require 'congestion/redis_pool'
Dir['./spec/support/**/*.rb'].sort.each{ |f| require f }

$REDIS_CONFIG = {
  url: ENV.fetch('CONGESTION_REDIS_URL', 'redis://localhost/0')
}

Congestion.redis = ->{
  Redis.new $REDIS_CONFIG
}

Congestion::RedisPool.redis_config = $REDIS_CONFIG

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
  config.before(:each){ Timecop.freeze }
  config.after(:each){ Timecop.return }
end
