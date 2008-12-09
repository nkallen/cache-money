module Cash
  class Mock < HashWithIndifferentAccess
    attr_accessor :servers

    def get_multi(*values)
      reject { |k,v| !values.include? k }
    end

    def []=(key, value)
      super(key, deep_clone(value))
    end

    def [](key)
      deep_clone(super(key))
    end

    def set(key, value, *options)
      self[key] = value
    end

    def get(key, *args)
      self[key]
    end

    def incr(key, amount = 1)
      self[key] ||= '0'
      self[key] = (self[key].to_i + amount).to_s
    end

    def decr(key, amount = 1)
      self[key] ||= '0'
      self[key] = (self[key].to_i - amount).to_s
    end

    def add(key, value, *options)
      if self[key]
        "NOT_STORED\r\n"
      else
        self[key] = value
        "STORED\r\n"
      end
    end

    def delete(key, *options)
      self[key] = nil
    end

    def append(key, value)
      set(key, get(key).to_s + value.to_s)
    end

    def namespace
      nil
    end

    def flush_all
      clear
    end

    def stats
      {}
    end

    def reset_runtime
      [0, Hash.new(0)]
    end

    private

    def marshal(obj)
      Marshal.dump(obj)
    end

    def unmarshal(marshaled_obj)
      Marshal.load(marshaled_obj)
    end

    def deep_clone(obj)
      unmarshal(marshal(obj))
    end
  end
end
