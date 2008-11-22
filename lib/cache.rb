$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'cache/lock'
require 'cache/transactional'
require 'cache/write_through'
require 'cache/finders'
require 'cache/buffered'
require 'cache/index_spec'
require 'cache/config'
require 'cache/accessor'

require 'cache/util/array'

class ActiveRecord::Base
  def self.is_cached(options = {})
    include Cache
    self.cache_config = options
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
    repository.transaction { transaction_without_cache_transaction(&block) }
  end
end