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
            alias_method_chain :find_every, :cache
            alias_method_chain :find_from_ids, :cache
            alias_method_chain :calculate, :cache
          end
        end
      end

      # User.find(:first, ...), User.find_by_foo(...), User.find(:all, ...), User.find_all_by_foo(...)
      def find_every_with_cache(options)
        Query.new(self, options, scope(:find)).miss do
          find_every_without_cache(options)
        end.uncacheable do
          find_every_without_cache(options)
        end.perform
      end

      # User.find(1), User.find(1, 2, 3), User.find([1, 2, 3]), User.find([])
      def find_from_ids_with_cache(ids, options)
        PrimaryKeyQuery.new(self, ids, options, scope(:find)).perform
      end

      # User.count(:all), User.count, User.sum(...)
      def calculate_with_cache(operation, column_name, options = {})
        Calculation.new(self, operation, column_name, options, scope(:find)).perform do
          calculate_without_cache(operation, column_name, options)
        end
      end
    end
  end
end