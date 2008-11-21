$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'cache/lock'
require 'cache/transactional'
require 'cache/write_through'
require 'cache/finders'
require 'cache/buffered'
require 'cache/coordinator'

require 'cache/util/array'

class ActiveRecord::Base
  class << self
    def index(options = {})
      include Cache::Coordinator
      self.cache_config = options
    end
  end
end