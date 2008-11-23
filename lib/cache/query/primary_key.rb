module Cache
  module Query
    class PrimaryKey < Abstract
      def initialize(klass, ids, options1, options2)
        super(klass, options1, options2)
        @expects_array = ids.first.kind_of?(Array)
        @ids = ids.flatten.compact.uniq.collect(&:to_i)
      end

      def perform
        return [] if @ids.empty?
        super({:conditions => { :id => @ids.first }}, {}, method(:find_from_keys), lambda {
          @klass.send :find_from_ids_without_cache, @ids, @options1
        })
      end

      private
      def normalize_objects(objects)
        convert_to_active_record_collection(super(objects))
      end

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
end