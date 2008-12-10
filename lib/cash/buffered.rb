module Cash
  class Buffered
    def self.push(cache, lock)
      if cache.is_a?(Buffered)
        cache.push
      else
        Buffered.new(cache, lock)
      end
    end

    def initialize(memcache, lock)
      @buffer = {}
      @commands = []
      @cache = memcache
      @lock = lock
    end

    def pop
      @cache
    end

    def push
      NestedBuffered.new(self, @lock)
    end

    def get(key, *options)
      if @buffer.has_key?(key)
        @buffer[key]
      else
        @buffer[key] = @cache.get(key, *options)
      end
    end

    def set(key, value, *options)
      @buffer[key] = value
      buffer_command Command.new(:set, key, value, *options)
    end

    def incr(key, amount = 1)
      return unless value = get(key, true)

      @buffer[key] = value.to_i + amount
      buffer_command Command.new(:incr, key, amount)
      @buffer[key]
    end

    def decr(key, amount = 1)
      return unless value = get(key, true)

      @buffer[key] = [value.to_i - amount, 0].max
      buffer_command Command.new(:decr, key, amount)
      @buffer[key]
    end

    def add(key, value, *options)
      @buffer[key] = value
      buffer_command Command.new(:add, key, value, *options)
    end

    def delete(key, *options)
      @buffer[key] = nil
      buffer_command Command.new(:delete, key, *options)
    end

    def get_multi(keys)
      values = keys.collect { |key| get(key) }
      keys.zip(values).to_hash
    end

    def flush
      sorted_keys = @commands.select(&:requires_lock?).collect(&:key).uniq.sort
      sorted_keys.each do |key|
        @lock.acquire_lock(key)
      end
      perform_commands
    ensure
      @buffer = {}
      sorted_keys.each do |key|
        @lock.release_lock(key)
      end
    end

    def method_missing(method, *args, &block)
      @cache.send(method, *args, &block)
    end

    def respond_to?(method)
      @cache.respond_to?(method)
    end

    protected
    def perform_commands
      @commands.each do |command|
        command.call(@cache)
      end
    end

    def buffer_command(command)
      @commands << command
    end
  end

  class NestedBuffered < Buffered
    def flush
      perform_commands
    end
  end

  class Command
    attr_accessor :key

    def initialize(name, key, *args)
      @name = name
      @key = key
      @args = args
    end

    def requires_lock?
      @name == :set
    end

    def call(cache)
      cache.send @name, @key, *@args
    end
  end
end
