module Cache
  module Accessor
    def self.included(a_module)
      a_module.module_eval do
        extend ClassMethods
      end
    end
    
    module ClassMethods
      def get(keys, options = {}, &block)
        case keys
        when Array
          keys.collect! { |key| cache_key(key) }
          hits = cache_repository.get_multi(keys)
          if (missed_keys = keys - hits.keys).any?
            missed_values = block.call(*missed_keys)
            hits.merge!(Hash[*missed_keys.zip(Array(missed_values)).flatten])
          end
          hits
        else
          cache_repository.get(cache_key(keys), options[:raw]) || (block ? block.call : nil)
        end
      end

      def set(key, value, ttl)
        cache_repository.set(cache_key(key), value, ttl)
      end
    
      def incr(key, delta = 1)
        cache_repository.incr(cache_key(key), delta) ||
          cache_repository.set(cache_key(key), delta) && cache_repository.incr(cache_key(key), delta)
      end

      def expire(key)
        cache_repository.delete(cache_key(key))
      end

      def cache_key(postfix)
        "#{name}/#{postfix.gsub(' ', '+')}"
      end
    end
  end
end
