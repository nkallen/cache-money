module Cash
  module Query
    class Calculation < Abstract
      delegate :calculate_without_cache, :incr, :to => :@active_record

      def initialize(active_record, operation, column, options1, options2)
        super(active_record, options1, options2)
        @operation, @column = operation, column
      end

      def perform
        super({}, :raw => true)
      end

      def calculation?
        true
      end

      protected
      def miss(_, __)
        calculate_without_cache(@operation, @column, @options1)
      end

      def uncacheable
        calculate_without_cache(@operation, @column, @options1)
      end

      def format_results(_, objects)
        objects.to_i
      end

      def serialize_objects(_, objects)
        objects.to_s
      end

      def cacheable?(*optionss)
        @column == :all && super(*optionss)
      end

      def cache_keys(attribute_value_pairs)
        "#{super(attribute_value_pairs)}/#{@operation}"
      end
    end
  end
end
