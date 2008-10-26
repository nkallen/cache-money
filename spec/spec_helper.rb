dir = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{dir}/../lib"

require 'rubygems'
require 'spec'
require 'pp'
require 'cache'
require 'memcache'

Spec::Runner.configure do |config|  
  config.mock_with :rr
  config.before do
    config = YAML.load(IO.read((File.expand_path(File.dirname(__FILE__) + "/../config/memcache.yml"))))['test']
    @memcache = MemCache.new(config)
    @memcache.servers = config['servers']
    @memcache.flush_all
  end
end