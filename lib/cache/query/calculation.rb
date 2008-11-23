module Cache
  module Query
    class Calculation < Abstract
      def initialize(active_record, operation, column, options1, options2)
        super(active_record, options1, options2)
        @operation, @column = operation, column
      end

      def perform(&block)
        super({}, { :raw => true }, block, block)
      end

      protected
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