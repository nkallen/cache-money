module Cache
  module Config
    def self.included(a_module)
      a_module.module_eval do
        extend ClassMethods
        delegate :cache_repository, :to => "self.class"
      end
    end
    
    module ClassMethods
      def cache_config=(config)
        write_inheritable_attribute :cache_config, config
      end

      def indices
        @indices ||= begin
          indices = cache_config[:on] || []
          Array(indices).collect { |i| Array(i).collect {|x| x.to_s }.sort }
        end
      end

      def cache_repository
        cache_config[:repository]
      end
    end
  end
end
