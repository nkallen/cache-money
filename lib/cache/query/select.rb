module Cache
  module Query
    class Select < Abstract
      def miss(&block)
        @miss = block; self
      end
  
      def uncacheable(&block)
        @uncacheable = block; self
      end
    end
  end
end