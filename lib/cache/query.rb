module Cache
  class Query
    extend ActiveSupport::Memoizable
    
    def initialize(klass, options1, options2)
      @klass, @options1, @options2 = klass, options1, options2 || {}
    end
    
    def cacheable?
      if safe_options_for_cache?(@options1) && safe_options_for_cache?(@options2)
        return unless partial_index_1 = attribute_value_pairs_for_conditions(@options1[:conditions])
        return unless partial_index_2 = attribute_value_pairs_for_conditions(@options2[:conditions])
        @attribute_value_pairs = (partial_index_1 + partial_index_2).sort { |x, y| x[0] <=> y[0] }
        indexed_on?(@attribute_value_pairs.collect { |pair| pair[0] })
      end
    end
    memoize :cacheable?
    
    def cache_key
      cacheable? && @attribute_value_pairs.flatten.join('/')
    end
    memoize :cache_key
    
    private
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
end
