module Cache
  module WriteThrough
    DEFAULT_TTL = 12.hours

    def self.included(active_record_class)
      active_record_class.class_eval do
        include InstanceMethods
        extend ClassMethods
      end
    end

    module InstanceMethods
      def self.included(active_record_class)
        active_record_class.class_eval do
          after_create :add_to_cache
          after_update :update_cache
          after_destroy :remove_from_cache
        end
      end

      def add_to_cache
        InstanceMethods.unfold(self.class) { |klass| klass.add_to_cache(self) }
      end

      def update_cache
        InstanceMethods.unfold(self.class) { |klass| klass.update_cache(self) }
      end

      def remove_from_cache
        return if new_record?

        InstanceMethods.unfold(self.class) { |klass| klass.remove_from_cache(self) }
      end

      def shallow_clone
        clone = self.class.new
        clone.instance_variable_set("@attributes", instance_variable_get(:@attributes))
        clone.instance_variable_set("@new_record", new_record?)
        clone
      end

      private
      def self.unfold(klass)
        while klass < ActiveRecord::Base && klass.ancestors.include?(WriteThrough)
          yield klass
          klass = klass.superclass
        end
      end
    end

    module ClassMethods
      def add_to_cache(object)
        indices.each { |index| index.add(object) }
      end

      def update_cache(object)
        indices.each { |index| index.update(object) }
      end

      def remove_from_cache(object)
        indices.each { |index| index.remove(object) }
      end
    end
  end
end
