module Cache
  module Coordinator
    DEFAULT_TTL = 12.hours

    def self.included(active_record_class)
      active_record_class.class_eval do
        extend ClassMethods
        delegate :ttl, :set, :get, :indices, :to => "self.class"
        include WriteThrough, Finders

        class_inheritable_reader :cache_config
      end
    end

    module ClassMethods
      def self.extended(active_record_class)
        active_record_class.class_eval do
          class << self
            alias_method_chain :transaction, :cache_transaction
          end
        end
      end

      module Config
        def cache_config=(config)
          write_inheritable_attribute :cache_config, config
        end

        def indices
          @indices ||= begin
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
      end
      include Config

      module Accessors
        def get(keys, &block)
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
            cache_repository.get(cache_key(keys)) || (block ? block.call : nil)
          end
        end

        def set(key, value, ttl)
          cache_repository.set(cache_key(key), value, ttl)
        end

        def expire(key)
          cache_repository.delete(cache_key(key))
        end

        def cache_key(postfix)
          "#{base_class.name}/#{postfix.gsub(' ', '+')}"
        end
      end
      include Accessors

      def transaction_with_cache_transaction(&block)
        cache_repository.transaction { transaction_without_cache_transaction(&block) }
      end
    end
  end
end
