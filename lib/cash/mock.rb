module Cash
  class Mock < HashWithIndifferentAccess
    attr_accessor :servers

    def get_multi(keys)
      slice(*keys).collect { |k,v| [k, Marshal.load(v)] }.to_hash
    end

    def set(key, value, ttl = 0, raw = false)
      self[key] = marshal(value, raw)
    end

    def get(key, raw = false)
      if raw
        self[key]
      else
        if self.has_key?(key)
          Marshal.load(self[key])
        else
          nil
        end
      end
    end

    def incr(key, amount = 1)
      if self.has_key?(key)
        self[key] = (self[key].to_i + amount).to_s
        self[key].to_i
      end
    end

    def decr(key, amount = 1)
      if self.has_key?(key)
        self[key] = (self[key].to_i - amount).to_s
        self[key].to_i
      end
    end

    def add(key, value, ttl = 0, raw = false)
      if self.has_key?(key)
        "NOT_STORED\r\n"
      else
        self[key] = marshal(value, raw)
        "STORED\r\n"
      end
    end

    def append(key, value)
      set(key, get(key, true).to_s + value.to_s, nil, true)
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

    def marshal(value, raw)
      if raw
        value.to_s
      else
        Marshal.dump(value)
      end
    end

    def unmarshal(marshaled_obj)
      Marshal.load(marshaled_obj)
    end

    def deep_clone(obj)
      unmarshal(marshal(obj))
    end
  end
end
