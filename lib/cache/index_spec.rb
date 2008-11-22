module Cache
  class IndexSpec
    attr_reader :attributes, :options
    delegate :each, :to => :@attributes
    
    def initialize(attributes, options = {})
      @attributes = Array(attributes).collect(&:to_s).sort
      @options = options
    end
    
    def ==(other)
      case other
      when IndexSpec
        attributes == other.attributes
      else
        attributes == other
      end
    end
  end
end
