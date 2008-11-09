$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'cache/lock'
require 'cache/transactional'
require 'cache/write_through'
require 'cache/finders'
require 'cache/buffered'

class ActiveRecord::Base
  class << self
    def index(options = {})
      include Cache::Coordinator
      write_inheritable_attribute :cache_config, options
    end
  end
end

module Cache
  module Coordinator
    DEFAULT_TTL = 12.hours
    
    def self.included(active_record_class)
      active_record_class.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods
      def self.included(active_record_class)
        active_record_class.class_eval do
          include WriteThrough
          delegate :ttl, :set, :fetch_cache, :to => "self.class"
        end
      end
    end
    
    module ClassMethods
      def self.extended(active_record_class)
        active_record_class.class_eval do
          class << self
            alias_method_chain :transaction, :cache_transaction
          end
                  
          include Finders
        end
      end
      
      def cache_config
        read_inheritable_attribute :cache_config
      end
      
      def indices
        @indicies ||= begin
          indices = cache_config[:on] || []
          Array(indices).collect { |i| Array(i).collect {|x| x.to_s }.sort }
        end
      end
      
      def ttl
        DEFAULT_TTL
      end
      
      def cache_repository
        cache_config[:repository]
      end
      
      def fetch_cache(key, &block)
        cache_repository.get(cache_key(key)) || begin
          (block || lambda { nil }).call
        end
      end
      
      def set(key, value, ttl)
        cache_repository.set(cache_key(key), value, ttl)
      end
      
      def expire_cache(key)
        cache_repository.delete(cache_key(key))
      end
      
      def cache_key(postfix)
        "#{name}:#{postfix.gsub(' ', '+')}"
      end
      
      def transaction_with_cache_transaction(&block) 
        cache_repository.transaction { transaction_without_cache_transaction(&block) }
      end
    end
  end
end
