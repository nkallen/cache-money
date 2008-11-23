module Cache
  class IndexSpec
    attr_reader :attributes, :options
    delegate :each, :hash, :to => :@attributes
    delegate :get, :set, :find_every_without_cache, :calculate_without_cache, :incr, :decr, :to => :@active_record

    DEFAULT_OPTIONS = { :ttl => 1.day }

    def initialize(config, active_record, attributes, options = {})
      @config, @active_record, @attributes, @options = config, active_record, Array(attributes).collect(&:to_s).sort, DEFAULT_OPTIONS.merge(options)
    end

    def ==(other)
      case other
      when IndexSpec
        attributes == other.attributes
      else
        attributes == other
      end
    end
    alias_method :eql?, :==

    def add(object)
      clone = object.shallow_clone
      _, new_attribute_value_pairs = old_and_new_attribute_value_pairs(object)
      add_to_index_with_minimal_network_operations(new_attribute_value_pairs, clone)
    end

    def update(object)
      clone = object.shallow_clone
      old_attribute_value_pairs, new_attribute_value_pairs = old_and_new_attribute_value_pairs(object)
      update_index_with_minimal_network_operations(old_attribute_value_pairs, new_attribute_value_pairs, clone)
    end

    def remove(object)
      old_attribute_value_pairs, _ = old_and_new_attribute_value_pairs(object)
      remove_object_from_cache(old_attribute_value_pairs, object)
    end

    def ttl
      @ttl ||= options[:ttl] || config.ttl
    end
    
    def order
      @order ||= options[:order] || :asc
    end

    def serialize_object(object)
      primary_key? ? object : object.id
    end
    
    def matches?(query)
      query.order == ['id', order]
    end

    private
    def old_and_new_attribute_value_pairs(object)
      old_attribute_value_pairs = []
      new_attribute_value_pairs = []
      @attributes.each do |name|
        new_value = object.attributes[name]
        original_value = object.send("#{name}_was")
        old_attribute_value_pairs << [name, original_value]
        new_attribute_value_pairs << [name, new_value]
      end
      [old_attribute_value_pairs, new_attribute_value_pairs]
    end

    def add_to_index_with_minimal_network_operations(attribute_value_pairs, object)
      if primary_key?
        add_object_to_primary_key_cache(attribute_value_pairs, object)
      else
        add_object_to_cache(attribute_value_pairs, object)
      end
    end

    def primary_key?
      @attributes.size == 1 && @attributes.first == "id"
    end

    def add_object_to_primary_key_cache(attribute_value_pairs, object)
      set(cache_key(attribute_value_pairs), [object], :ttl => ttl)
    end

    def cache_key(attribute_value_pairs)
      attribute_value_pairs.flatten.join('/')
    end

    def add_object_to_cache(attribute_value_pairs, object, overwrite = true)
      return if invalid_cache_key?(attribute_value_pairs)

      key, cache_value, cache_hit = get_key_and_value_at_index(attribute_value_pairs)
      if !cache_hit || overwrite
        object_to_add = serialize_object(object)
        value = (cache_value + [object_to_add]).sort do |a, b|
          (a <=> b) * (order == :asc ? 1 : -1)
        end.uniq
        set(key, value, :ttl => ttl)
        incr("#{key}/count") { calculate_at_index(:count, attribute_value_pairs) }
      end
    end

    def invalid_cache_key?(attribute_value_pairs)
      attribute_value_pairs.collect { |_,value| value }.any? { |x| x.nil? }
    end

    def get_key_and_value_at_index(attribute_value_pairs)
      key = cache_key(attribute_value_pairs)
      cache_hit = true
      cache_value = get(key) do
        cache_hit = false
        conditions = Hash[*attribute_value_pairs.flatten]
        find_every_without_cache(:select => :id, :conditions => conditions).collect do |object|
          serialize_object(object)
        end
      end
      [key, cache_value, cache_hit]
    end

    def calculate_at_index(operation, attribute_value_pairs)
      conditions = Hash[*attribute_value_pairs.flatten]
      calculate_without_cache(operation, :all, :conditions => conditions)
    end

    def update_index_with_minimal_network_operations(old_attribute_value_pairs, new_attribute_value_pairs, object)
      if index_is_stale?(old_attribute_value_pairs, new_attribute_value_pairs)
        remove_object_from_cache(old_attribute_value_pairs, object)
        add_object_to_cache(new_attribute_value_pairs, object)
      elsif primary_key?
        add_object_to_primary_key_cache(new_attribute_value_pairs, object)
      else
        add_object_to_cache(new_attribute_value_pairs, object, false)
      end
    end

    def remove_object_from_cache(attribute_value_pairs, object)
      return if invalid_cache_key?(attribute_value_pairs)

      key, cache_value, _ = get_key_and_value_at_index(attribute_value_pairs)
      object_to_remove = serialize_object(object)
      set(key, (cache_value - [object_to_remove]), :ttl => ttl)
      decr("#{key}/count") { calculate_at_index(:count, attribute_value_pairs) }
    end

    def index_is_stale?(old_attribute_value_pairs, new_attribute_value_pairs)
      old_attribute_value_pairs != new_attribute_value_pairs
    end
  end
end
