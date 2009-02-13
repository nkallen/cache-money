module Cash
  class Lock
    class Error < RuntimeError; end
    INITIAL_WAIT = 1
    DEFAULT_RETRY = 5
    DEFAULT_EXPIRY = 30

    def initialize(cache)
      @cache = cache
    end

    def synchronize(key, lock_expiry = DEFAULT_EXPIRY, retries = DEFAULT_RETRY, initial_wait = INITIAL_WAIT)
      if recursive_lock?(key)
        yield
      else
        acquire_lock(key, lock_expiry, retries, initial_wait)
        begin
          yield
        ensure
          release_lock(key)
        end
      end
    end

    def acquire_lock(key, lock_expiry = DEFAULT_EXPIRY, retries = DEFAULT_RETRY, initial_wait = INITIAL_WAIT)
      retries.times do |count|
        return if @cache.add("lock/#{key}", Process.pid, lock_expiry)
        raise Error if count == retries - 1
        exponential_sleep(count, initial_wait) unless count == retries - 1
      end
      raise Error, "Couldn't acquire memcache lock for: #{key}"
    end

    def release_lock(key)
      @cache.delete("lock/#{key}")
    end

    def exponential_sleep(count, initial_wait)
      sleep((2**count) * initial_wait)
    end

    private

    def recursive_lock?(key)
      @cache.get("lock/#{key}") == Process.pid
    end

  end
end
