module Cash
  class Local
    delegate :respond_to?, :to => :@remote_cache

    def initialize(remote_cache)
      @remote_cache = remote_cache
    end

    def cache_locally
      @remote_cache = LocalBuffer.new(original_cache = @remote_cache)
      yield
    ensure
      @remote_cache = original_cache
    end

    def method_missing(method, *args, &block)
      @remote_cache.send(method, *args, &block)
    end
  end

  class LocalBuffer
    delegate :respond_to?, :to => :@remote_cache

    def initialize(remote_cache)
      @local_cache = {}
      @remote_cache = remote_cache
    end

    def get(key, *options)
      if @local_cache.has_key?(key)
        @local_cache[key]
      else
        @local_cache[key] = @remote_cache.get(key, *options)
      end
    end

    def set(key, value, *options)
      @remote_cache.set(key, value, *options)
      @local_cache[key] = value
    end

    def add(key, value, *options)
      result = @remote_cache.add(key, value, *options)
      if result == "STORED\r\n"
        @local_cache[key] = value
      end
      result
    end

    def delete(key, *options)
      @remote_cache.delete(key, *options)
      @local_cache.delete(key)
    end

    def method_missing(method, *args, &block)
      @remote_cache.send(method, *args, &block)
    end
  end
end
