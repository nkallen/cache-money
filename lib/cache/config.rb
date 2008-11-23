module Cache
  module Config
    def self.included(a_module)
      a_module.module_eval do
        extend ClassMethods
        delegate :repository, :to => "self.class"
      end
    end
    
    module ClassMethods
      def self.extended(a_class)
        a_class.class_eval do
          class << self
            delegate :repository, :indices, :to => :@cache_config
            alias_method_chain :inherited, :cache_config
          end
        end
      end
      
      def inherited_with_cache_config(subclass)
        inherited_without_cache_config(subclass)
        @cache_config.dup(subclass)
      end
      
      def index(attributes, options = {})
        @cache_config.indices << Cache::IndexSpec.new(@cache_config, self, attributes, options)
      end
      
      def cache_config=(config)
        @cache_config = config
      end
    end
    
    class Config
      attr_reader :active_record, :options

      def self.create(active_record, options)
        active_record.cache_config = new(active_record, options)
        active_record.index :id
      end
      
      def initialize(active_record, options = {})
        @active_record = active_record
        @options = options
      end
      
      def repository
        @options[:repository]
      end
      
      def indices
        @options[:indices] ||= []
      end
      
      def options
        @options.dup.merge(:indices => @options[:indices].dup)
      end
      
      def dup(active_record)
        active_record.cache_config = self.class.new(active_record, options.except(:indices))
        indices.each { |i| active_record.index i.attributes, i.options }
      end
    end
  end
end
