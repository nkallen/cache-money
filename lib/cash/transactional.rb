module Cash
  class Transactional
    attr_reader :memcache

    def initialize(memcache, lock)
      @memcache, @cache = [memcache, memcache]
      @lock = lock
    end

    def transaction
      exception_was_raised = false
      begin_transaction
      result = yield
    rescue Object => e
      exception_was_raised = true
      raise
    ensure
      @cache.flush unless exception_was_raised
      end_transaction
    end

    def method_missing(method, *args, &block)
      @cache.send(method, *args, &block)
    end

    def respond_to?(method)
      @cache.respond_to?(method)
    end

    private
    def begin_transaction
      @cache = Buffered.push(@cache, @lock)
    end

    def end_transaction
      @cache = @cache.pop
    end
  end
end
