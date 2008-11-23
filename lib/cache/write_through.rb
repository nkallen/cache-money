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
        clone = object.shallow_clone
        indices.each do |attributes_in_the_index|
          _, new_attribute_value_pairs = old_and_new_attribute_value_pairs(attributes_in_the_index, object)
          add_to_index_with_minimal_network_operations(new_attribute_value_pairs, clone)
        end
      end

      def update_cache(object)
        clone = object.shallow_clone
        indices.each do |attributes_in_the_index|
          old_attribute_value_pairs, new_attribute_value_pairs = old_and_new_attribute_value_pairs(attributes_in_the_index, object)
          update_index_with_minimal_network_operations(old_attribute_value_pairs, new_attribute_value_pairs, clone)
        end
      end

      def remove_from_cache(object)
        indices.each do |attributes_in_the_index|
          old_attribute_value_pairs, _ = old_and_new_attribute_value_pairs(attributes_in_the_index, object)
          remove_object_from_cache(old_attribute_value_pairs, object)
        end
      end

      private
      def cache_key_for_index(attribute_value_pairs)
        attribute_value_pairs.flatten.join('/')
      end
      
      def old_and_new_attribute_value_pairs(attributes_in_the_index, object)
        old_attribute_value_pairs = []
        new_attribute_value_pairs = []
        attributes_in_the_index.each do |name|
          new_value = object.attributes[name]
          original_value = object.send("#{name}_was")
          old_attribute_value_pairs << [name, original_value]
          new_attribute_value_pairs << [name, new_value]
        end
        [old_attribute_value_pairs, new_attribute_value_pairs]
      end

      def add_to_index_with_minimal_network_operations(attribute_value_pairs, object)
        if primary_key?(attribute_value_pairs)
          add_object_to_primary_key_cache(attribute_value_pairs, object)
        else
          add_object_to_cache(attribute_value_pairs, object)
        end
      end

      def add_object_to_primary_key_cache(attribute_value_pairs, object)
        key = cache_key_for_index(attribute_value_pairs)
        set(key, [object], DEFAULT_TTL)
      end

      def add_object_to_cache(attribute_value_pairs, object, overwrite = true)
        return if invalid_cache_key?(attribute_value_pairs)

        key, cache_value, cache_hit = get_key_and_value_at_index(attribute_value_pairs)
        if !cache_hit || overwrite
          object_to_add = serializable_object_formatted_for_index(attribute_value_pairs, object)
          set(key, (cache_value + [object_to_add]).uniq, DEFAULT_TTL)
          incr("#{key}/count") { calculate_at_index(:count, attribute_value_pairs) }
        end
      end

      def invalid_cache_key?(attribute_value_pairs)
        attribute_value_pairs.collect { |_,value| value }.any? { |x| x.nil? }
      end

      def update_index_with_minimal_network_operations(old_attribute_value_pairs, new_attribute_value_pairs, object)
        if index_is_stale?(old_attribute_value_pairs, new_attribute_value_pairs)
          remove_object_from_cache(old_attribute_value_pairs, object)
          add_object_to_cache(new_attribute_value_pairs, object)
        elsif primary_key?(old_attribute_value_pairs)
          add_object_to_primary_key_cache(new_attribute_value_pairs, object)
        else
          add_object_to_cache(new_attribute_value_pairs, object, false)
        end
      end

      def remove_object_from_cache(attribute_value_pairs, object)
        return if invalid_cache_key?(attribute_value_pairs)

        key, cache_value, _ = get_key_and_value_at_index(attribute_value_pairs)
        object_to_remove = serializable_object_formatted_for_index(attribute_value_pairs, object)
        set(key, (cache_value - [object_to_remove]).uniq, DEFAULT_TTL)
        decr("#{key}/count") { calculate_at_index(:count, attribute_value_pairs) }
      end

      def index_is_stale?(old_attribute_value_pairs, new_attribute_value_pairs)
        old_attribute_value_pairs != new_attribute_value_pairs
      end

      def primary_key?(attribute_value_pairs)
        attribute_value_pairs.size == 1 && attribute_value_pairs.first.first.to_s == "id"
      end

      def serializable_object_formatted_for_index(attribute_value_pairs, object)
        primary_key?(attribute_value_pairs) ? object : object.id
      end

      def get_key_and_value_at_index(attribute_value_pairs)
        key = cache_key_for_index(attribute_value_pairs)
        cache_hit = true
        cache_value = get(key) do
          cache_hit = false
          conditions = Hash[*attribute_value_pairs.flatten]
          find_every_without_cache(:select => 'id', :conditions => conditions).collect do |object|
            serializable_object_formatted_for_index(attribute_value_pairs, object)
          end
        end
        [key, cache_value, cache_hit]
      end
      
      def calculate_at_index(operation, attribute_value_pairs)
        conditions = Hash[*attribute_value_pairs.flatten]
        calculate_without_cache(operation, :all, :conditions => conditions)
      end
    end
  end
end