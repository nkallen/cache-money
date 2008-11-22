$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'cache/lock'
require 'cache/transactional'
require 'cache/write_through'
require 'cache/finders'
require 'cache/buffered'
require 'cache/config'
require 'cache/accessor'

require 'cache/util/array'

class ActiveRecord::Base
  class << self
    def index(options = {})
      include Cache unless ancestors.include?(Cache)
      self.cache_config = options
    end
  end
end

module Cache
  def self.included(active_record_class)
    active_record_class.class_eval do
      include Config, Accessor, WriteThrough, Finders
      class_inheritable_reader :cache_config
      alias_method_chain :transaction, :cache_transaction
    end
  end
  
  def transaction_with_cache_transaction(&block)
    cache_repository.transaction { transaction_without_cache_transaction(&block) }
  end
end