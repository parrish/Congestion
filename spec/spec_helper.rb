$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'rspec/its'
require 'congestion'
Dir['./spec/support/**/*.rb'].sort.each{ |f| require f }
