module Marshal
  class << self
    def constantize(name)
      name.constantize
    end

    def load_with_constantize(value)
      begin
        Marshal.load_without_constantize value
      rescue ArgumentError => e
        _, class_name = *(/undefined class\/module (\w+)/.match(e.message))
        raise if !class_name
        constantize(class_name)
        Marshal.load value
      end
    end
    alias_method_chain :load, :constantize
  end
end
