module Cache
  class Query
    extend ActiveSupport::Memoizable
    
    def initialize(klass, options1, options2)
      @klass, @options1, @options2 = klass, options1, options2 || {}
    end
    
    def miss(&block)
      @miss = block; self
    end
    
    def uncacheable(&block)
      @uncacheable = block; self
    end

    def perform
      if cacheable?(@options1, @options2)
        cache_keys = cache_key
        objects = @klass.get(cache_keys) { |*missed_keys| @miss.call(missed_keys) }
        objects = convert_to_array(cache_keys, objects)
        objects = apply_limits_and_offsets(objects, @options1)
        deserialize_objects(objects)
      else
        @uncacheable.call
      end
    end
    
    protected
    module Safety
      def cacheable?(options1, options2)
        if safe_options_for_cache?(options1) && safe_options_for_cache?(options2)
          return unless partial_index_1 = attribute_value_pairs_for_conditions(options1[:conditions])
          return unless partial_index_2 = attribute_value_pairs_for_conditions(options2[:conditions])
          @attribute_value_pairs = (partial_index_1 + partial_index_2).sort { |x, y| x[0] <=> y[0] }
          indexed_on?(@attribute_value_pairs.collect { |pair| pair[0] })
        end
      end
    
      def cache_key
        @attribute_value_pairs.flatten.join('/')
      end
    
      def safe_options_for_cache?(options)
        return false unless options.kind_of?(Hash)
        options.except(:conditions, :readonly, :limit, :offset).values.compact.empty? && !options[:readonly]
      end

      def attribute_value_pairs_for_conditions(conditions)
        case conditions
        when Hash
          conditions.to_a.collect { |key, value| [key.to_s, value] }
        when String
          parse_indices_from_condition(conditions)
        when Array
          parse_indices_from_condition(*conditions)
        when NilClass
          []
        end
      end

      # Matches: id = 1 AND name = 'foo'
      AND = /\s+AND\s+/i
      # Matches: `users`.id = 123, `users`.`id` = 123, users.id = 123; id = 123, id = ?, id = '123', id = '12''3'; (id = 123)
      KEY_EQ_VALUE = /^\(?(?:`?(\w+)`?\.)?`?(\w+)`? = '?(\d+|\?|(?:(?:[^']|'')*))'?\)?$/
    
      def parse_indices_from_condition(conditions = '', *values)
        values = values.dup
        conditions.split(AND).inject([]) do |indices, condition|
          matched, table_name, column_name, sql_value = *(KEY_EQ_VALUE.match(condition))
          if matched && table_name_is_name_of_current_active_record_class?(table_name)
            value = sql_value == '?' ? values.shift : sql_value
            indices << [column_name, value]
          else
            return nil
          end
        end
      end

      def table_name_is_name_of_current_active_record_class?(table_name)
        !table_name || (table_name == @klass.table_name)
      end

      def indexed_on?(attributes)
        @klass.indices.include?(attributes)
      end
    end
    include Safety
    
    module Performance
      def convert_to_array(cache_keys, object)
        if object.kind_of?(Hash)
          cache_keys.collect { |key| object[@klass.cache_key(key)] }.flatten.compact
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
          objects = @klass.get(cache_keys, &method(:find_from_keys))
          convert_to_array(cache_keys, objects)
        end
      end
      
      def find_from_keys(*missing_keys)
        missing_ids = missing_keys.flatten.collect { |key| key.split('/')[2].to_i }
        @klass.send :find_from_ids_without_cache, missing_ids, {}
      end
    end
    include Performance
  end
  
  class Calculation < Query
    def initialize(klass, operation, column, options1, options2)
      @klass, @operation, @column, @options1, @options2 = klass, operation, column, options1, options2 || {}
    end
    
    def perform(&block)
      if cacheable?(@options1, @options2)
        missed_keys = nil
        objects = @klass.get(cache_key, :raw => true, &block).to_i
      else
        block.call
      end
    end

    protected
    def cacheable?(options1, options2)
      @column == :all && super(options1, options2)
    end
    
    def cache_key
      "#{super}/#{@operation}"
    end
  end
  
  class PrimaryKeyQuery < Query
    def initialize(klass, ids, options1, options2)
      @klass, @options1, @options2 = klass, options1, options2
      @expects_array = ids.first.kind_of?(Array)
      @ids = ids.flatten.compact.uniq.collect(&:to_i)
    end
    
    def perform
      return [] if @ids.empty?
      
      if cacheable?(@options1, :conditions => { :id => @ids.first })
        objects = @klass.get(cache_keys, &method(:find_from_keys))
        objects = convert_to_array(cache_keys, objects)
        objects = apply_limits_and_offsets(objects, @options1)
        objects = convert_to_active_record_collection(objects)
      else
        @klass.send :find_from_ids_without_cache, @ids, @options1
      end
    end
    
    private
    def cache_keys
      @ids.collect { |id| "id/#{id}" }
    end
    
    def convert_to_active_record_collection(objects)
      case objects.size
      when 0
        raise ActiveRecord::RecordNotFound
      when 1
        @expects_array ? objects : objects.first
      else
        objects
      end
    end
  end
end