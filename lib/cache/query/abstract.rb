module Cache
  module Query
    class Abstract
      delegate :get, :table_name, :indices, :find_from_ids_without_cache, :cache_key, :to => :@active_record
      
      def initialize(active_record, options1, options2)
        @active_record, @options1, @options2 = active_record, options1, options2 || {}
      end

      def perform(find_options = {}, get_options = {}, miss = @miss, uncacheable = @uncacheable)
        if cacheable?(@options1, @options2.merge(find_options))
          objects = get(cache_keys, get_options) { |*missed_keys| miss.call(missed_keys) }
          normalize_objects(objects)
        else
          uncacheable.call
        end
      end

      private
      def cacheable?(options1, options2)
        if safe_options_for_cache?(options1) && safe_options_for_cache?(options2)
          return unless partial_index_1 = attribute_value_pairs_for_conditions(options1[:conditions])
          return unless partial_index_2 = attribute_value_pairs_for_conditions(options2[:conditions])
          @attribute_value_pairs = (partial_index_1 + partial_index_2).sort { |x, y| x[0] <=> y[0] }
          indexed_on?(@attribute_value_pairs.collect { |pair| pair[0] })
        end
      end

      def cache_keys
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
        !table_name || (table_name == table_name)
      end

      def indexed_on?(attributes)
        indices.include?(attributes)
      end
    
      def normalize_objects(objects)
        objects = convert_to_array(cache_keys, objects)
        objects = apply_limits_and_offsets(objects, @options1)
        deserialize_objects(objects)
      end
    
      def convert_to_array(cache_keys, object)
        if object.kind_of?(Hash)
          cache_keys.collect { |key| object[cache_key(key)] }.flatten.compact
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