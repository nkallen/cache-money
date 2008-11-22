dir = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{dir}/../lib"

require 'rubygems'
require 'spec'
require 'pp'
require 'cache'
require 'memcache'
require File.join(dir, '../config/environment')

Spec::Runner.configure do |config|
  config.mock_with :rr
  config.before :suite do
    config = YAML.load(IO.read((File.expand_path(File.dirname(__FILE__) + "/../config/memcache.yml"))))['test']
    $memcache = MemCache.new(config)
    $memcache.servers = config['servers']
    $lock = Cache::Lock.new($memcache)
  end

  config.before :each do
    $memcache.flush_all
    Story.delete_all
    Character.delete_all
  end
  
  config.before :suite do
    Story = Class.new(ActiveRecord::Base)
    Character = Class.new(ActiveRecord::Base)
    Story.has_many :characters
    Story.index :on => [:id, :title, [:id, :title]], :repository => repository = Cache::Transactional.new($memcache, $lock)
    Character.index :on => [:id, [:name, :story_id], [:id, :story_id]], :repository => repository

    Epic = Class.new(Story)
    Oral = Class.new(Epic)
    Oral.index :on => [:id, :title], :repository => repository
    Story.has_many :characters
  end
end