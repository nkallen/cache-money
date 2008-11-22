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
    ActiveRecord::Base.class_eval do
      is_cached :repository => Cache::Transactional.new($memcache, $lock)
    end
    
    Character = Class.new(ActiveRecord::Base)
    Story = Class.new(ActiveRecord::Base)
    Story.has_many :characters
    
    Story.class_eval do
      index :title
      index [:id, :title]
    end

    Epic = Class.new(Story)
    Oral = Class.new(Epic)
    
    Character.class_eval do
      index [:name, :story_id]
      index [:id, :story_id]
    end
    
    Oral.class_eval do
      index :subtitle
    end
  end
end