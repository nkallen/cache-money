module Cash
  module Query
    class Abstract
      delegate :with_exclusive_scope, :get, :table_name, :indices, :find_from_ids_without_cache, :cache_key, :columns_hash, :to => :@active_record

      def self.perform(*args)
        new(*args).perform
      end

      def initialize(active_record, options1, options2)
        @active_record, @options1, @options2 = active_record, options1, options2 || {}
      end

      def perform(find_options = {}, get_options = {})
        if cache_config = cacheable?(@options1, @options2, find_options)
          cache_keys, index = cache_keys(cache_config[0]), cache_config[1]

          misses, missed_keys, objects = hit_or_miss(cache_keys, index, get_options)
          format_results(cache_keys, choose_deserialized_objects_if_possible(missed_keys, cache_keys, misses, objects))
        else
          uncacheable
        end
      end

      DESC = /DESC/i

      def order
        @order ||= begin
          if order_sql = @options1[:order] || @options2[:order]
            matched, table_name, column_name, direction = *(ORDER.match(order_sql))
            [column_name, direction =~ DESC ? :desc : :asc]
          else
            ['id', :asc]
          end
        end
      end

      def limit
        @limit ||= @options1[:limit] || @options2[:limit]
      end

      def offset
        @offset ||= @options1[:offset] || @options2[:offset] || 0
      end

      def calculation?
        false
      end

      private
      def cacheable?(*optionss)
        optionss.each { |options| return unless safe_options_for_cache?(options) }
        partial_indices = optionss.collect { |options| attribute_value_pairs_for_conditions(options[:conditions]) }
        return if partial_indices.include?(nil)
        attribute_value_pairs = partial_indices.sum.sort { |x, y| x[0] <=> y[0] }
        if index = indexed_on?(attribute_value_pairs.collect { |pair| pair[0] })
          if index.matches?(self)
            [attribute_value_pairs, index]
          end
        end
      end

      def hit_or_miss(cache_keys, index, options)
        misses, missed_keys = nil, nil
        objects = @active_record.get(cache_keys, options.merge(:ttl => index.ttl)) do |missed_keys|
          misses = miss(missed_keys, @options1.merge(:limit => index.window))
          serialize_objects(index, misses)
        end
        [misses, missed_keys, objects]
      end

      def cache_keys(attribute_value_pairs)
        attribute_value_pairs.flatten.join('/')
      end

      def safe_options_for_cache?(options)
        return false unless options.kind_of?(Hash)
        options.except(:conditions, :readonly, :limit, :offset, :order).values.compact.empty? && !options[:readonly]
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

      AND = /\s+AND\s+/i
      TABLE_AND_COLUMN = /(?:(?:`|")?(\w+)(?:`|")?\.)?(?:`|")?(\w+)(?:`|")?/              # Matches: `users`.id, `users`.`id`, users.id, id
      VALUE = /'?(\d+|\?|(?:(?:[^']|'')*))'?/                     # Matches: 123, ?, '123', '12''3'
      KEY_EQ_VALUE = /^\(?#{TABLE_AND_COLUMN}\s+=\s+#{VALUE}\)?$/ # Matches: KEY = VALUE, (KEY = VALUE)
      ORDER = /^#{TABLE_AND_COLUMN}\s*(ASC|DESC)?$/i              # Matches: COLUMN ASC, COLUMN DESC, COLUMN

      def parse_indices_from_condition(conditions = '', *values)
        values = values.dup
        conditions.split(AND).inject([]) do |indices, condition|
          matched, table_name, column_name, sql_value = *(KEY_EQ_VALUE.match(condition))
          if matched
            value = sql_value == '?' ? values.shift : columns_hash[column_name].type_cast(sql_value)
            indices << [column_name, value]
          else
            return nil
          end
        end
      end

      def indexed_on?(attributes)
        indices.detect { |index| index == attributes }
      end
      alias_method :index_for, :indexed_on?

      def format_results(cache_keys, objects)
        return objects if objects.blank?

        objects = convert_to_array(cache_keys, objects)
        objects = apply_limits_and_offsets(objects, @options1)
        deserialize_objects(objects)
      end

      def choose_deserialized_objects_if_possible(missed_keys, cache_keys, misses, objects)
        missed_keys == cache_keys ? misses : objects
      end

      def serialize_objects(index, objects)
        Array(objects).collect { |missed| index.serialize_object(missed) }
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
        missing_ids = Array(missing_keys).flatten.collect { |key| key.split('/')[2].to_i }
        find_from_ids_without_cache(missing_ids, {})
      end
    end
  end
end
