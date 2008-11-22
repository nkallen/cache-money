module Cache
  module Finders
    def self.included(active_record_class)
      active_record_class.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def self.extended(active_record_class)
        active_record_class.class_eval do
          class << self
            alias_method_chain :find_initial, :cache
            alias_method_chain :find_every, :cache
            alias_method_chain :find_from_ids, :cache
            alias_method_chain :calculate, :cache
          end
        end
      end

      # User.find(:first, ...), User.find_by_foo(...)
      def find_initial_with_cache(options)
        query = Query.new(self, options, scope(:find))
        if query.cacheable?
          find_with_cache(query.cache_key, options.merge(:limit => 1)) do
            find_every_without_cache(:conditions => options[:conditions])
          end.first
        else
          find_initial_without_cache(options)
        end
      end

      # User.find(:all, ...), User.find_all_by_foo(...)
      def find_every_with_cache(options)
        query = Query.new(self, options, scope(:find))
        if query.cacheable?
          find_with_cache(query.cache_key, options) do
            find_every_without_cache(:conditions => options[:conditions])
          end
        else
          find_every_without_cache(options)
        end
      end

      # User.find(1), User.find(1, 2, 3), User.find([1, 2, 3]), User.find([])
      def find_from_ids_with_cache(ids, options)
        expects_array = ids.first.kind_of?(Array)
        sanitized_ids = ids.flatten.compact.uniq.map { |x| x.to_i }

        cache_keys = sanitized_ids.collect do |id|
          Query.new(self, options, :conditions => {:id => id}).cache_key
        end.compact
        if !cache_keys.empty?
          objects = find_with_cache(cache_keys, options, &method(:find_from_keys))

          case objects.size
          when 0
            raise ActiveRecord::RecordNotFound
          when 1
            expects_array ? objects : objects.first
          else
            objects
          end
        else
          find_from_ids_without_cache(ids, options)
        end
      end

      # User.count(:all), User.count, User.sum(...)
      def calculate_with_cache(operation, column_name, options = {})
        query = Query.new(self, options, scope(:find))
        if column_name == :all && query.cacheable?
          get("#{query.cache_key}/#{operation}", :raw => true) do
            calculate_without_cache(operation, column_name, options)
          end.to_i
        else
          calculate_without_cache(operation, column_name, options)
        end
      end

      private
      def find_with_cache(cache_keys, options)
        missed_keys = nil
        objects = get(cache_keys) { |*missed_keys| yield(missed_keys) }
        objects = convert_to_array(cache_keys, objects)
        objects = apply_limits_and_offsets(objects, options)
        deserialize_objects(objects)
      end

      def convert_to_array(cache_keys, object)
        if object.kind_of?(Hash)
          cache_keys.collect { |key| object[key] }.flatten.compact
        else
          Array(object)
        end
      end

      def apply_limits_and_offsets(results, options)
        results.slice((options[:offset] || 0), (options[:limit] || results.length))
      end

      def deserialize_objects(objects)
        if objects.first.kind_of?(ActiveRecord::Base)
          objects
        else
          cache_keys = objects.collect { |id| "id/#{id}" }
          objects = get(cache_keys, &method(:find_from_keys))
          convert_to_array(cache_keys, objects)
        end
      end

      def find_from_keys(*missing_keys)
        missing_ids = missing_keys.flatten.collect { |key| key.split('/')[2].to_i }
        find_from_ids_without_cache(missing_ids, {})
      end
    end
  end
end