module Cash
  module Accessor
    def self.included(a_module)
      a_module.module_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module ClassMethods
      def fetch(keys, options = {}, &block)
        case keys
        when Array
          keys = keys.collect { |key| cache_key(key) }
          hits = repository.get_multi(keys)
          if (missed_keys = keys - hits.keys).any?
            missed_values = block.call(missed_keys)
            hits.merge!(Hash[*missed_keys.zip(Array(missed_values)).flatten])
          end
          hits
        else
          repository.get(cache_key(keys), options[:raw]) || (block ? block.call : nil)
        end
      end

      def get(keys, options = {}, &block)
        case keys
        when Array
          fetch(keys, options, &block)
        else
          fetch(keys, options) do
            if block_given?
              add(keys, result = yield(keys))
              result
            end
          end
        end
      end

      def add(key, value, options = {})
        repository.add(cache_key(key), value, options[:ttl] || 0, options[:raw])
      end

      def set(key, value, options = {})
        repository.set(cache_key(key), value, options[:ttl] || 0, options[:raw])
      end

      def incr(key, delta = 1, ttl = 0)
        repository.incr(cache_key(key), delta) || begin
          repository.set(cache_key(key), (result = yield).to_s, ttl, true)
          result
        end
      end
      
      def decr(key, delta = 1, ttl = 0)
        repository.decr(cache_key(key), delta) || begin
          repository.set(cache_key(key), (result = yield).to_s, ttl, true)
          result
        end
      end

      def expire(key)
        repository.delete(cache_key(key))
      end

      def cache_key(key)
        "#{name}/#{key.to_s.gsub(' ', '+')}"
      end
    end
    
    module InstanceMethods
      def expire
        self.class.expire(id)
      end
      alias_method :expire_cache, :expire
    end
  end
end
