require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe Transactional do
    before do
      @cache = Transactional.new($memcache, $lock)
      @value = "stuff to be cached"
      @key   = "key"
    end

    describe 'Basic Operations' do
      it "gets through the real cache" do
        $memcache.set(@key, @value)
        @cache.get(@key).should == @value
      end

      it "sets through the real cache" do
        mock($memcache).set(@key, @value, :option1, :option2)
        @cache.set(@key, @value, :option1, :option2)
      end

      it "increments through the real cache" do
        @cache.set(@key, 0)
        @cache.incr(@key, 3)

        @cache.get(@key, true).to_i.should == 3
        $memcache.get(@key, true).to_i.should == 3
      end

      it "decrements through the real cache" do
        @cache.set(@key, 0)
        @cache.incr(@key, 3)
        @cache.decr(@key, 2)

        @cache.get(@key, true).to_i.should == 1
        $memcache.get(@key, true).to_i.should == 1
      end

      it "adds through the real cache" do
        @cache.add(@key, @value)
        $memcache.get(@key).should == @value
        @cache.get(@key).should == @value

        @cache.add(@key, "another value")
        $memcache.get(@key).should == @value
        @cache.get(@key).should == @value
      end

      it "deletes through the real cache" do
        $memcache.add(@key, @value)
        $memcache.get(@key).should == @value

        @cache.delete(@key)
        $memcache.get(@key).should be_nil
      end

      it "returns true for respond_to? with what it responds to" do
        @cache.respond_to?(:get).should be_true
        @cache.respond_to?(:set).should be_true
        @cache.respond_to?(:get_multi).should be_true
        @cache.respond_to?(:incr).should be_true
        @cache.respond_to?(:decr).should be_true
        @cache.respond_to?(:add).should be_true
      end

      it "delegates unsupported messages back to the real cache" do
        mock($memcache).foo(:bar)
        @cache.foo(:bar)
      end

      describe '#get_multi' do
        describe 'when everything is a hit' do
          it 'returns a hash' do
            @cache.set('key1', @value)
            @cache.set('key2', @value)
            @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value, 'key2' => @value }
          end
        end

        describe 'when there are misses' do
          it 'only returns results for hits' do
            @cache.set('key1', @value)
            @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value }
          end
        end
      end
    end

    describe 'In a Transaction' do
      it "commits to the real cache" do
        $memcache.get(@key).should == nil
        @cache.transaction do
          @cache.set(@key, @value)
        end
        $memcache.get(@key).should == @value
      end

      describe 'when there is a return/next/break in the transaction' do
        it 'commits to the real cache' do
          $memcache.get(@key).should == nil
          @cache.transaction do
            @cache.set(@key, @value)
            next
          end
          $memcache.get(@key).should == @value
        end
      end

      it "reads through the real cache if key has not been written to" do
        $memcache.set(@key, @value)
        @cache.transaction do
          @cache.get(@key).should == @value
        end
        @cache.get(@key).should == @value
      end

      it "delegates unsupported messages back to the real cache" do
        @cache.transaction do
          mock($memcache).foo(:bar)
          @cache.foo(:bar)
        end
      end

      it "returns the result of the block passed to the transaction" do
        @cache.transaction do
          :result
        end.should == :result
      end

      describe 'Increment and Decrement' do
        describe '#incr' do
          it "works" do
            @cache.set(@key, 0)
            @cache.incr(@key)
            @cache.transaction do
              @cache.incr(@key).should == 2
            end
          end

          it "is buffered" do
            @cache.transaction do
              @cache.set(@key, 0)
              @cache.incr(@key, 2).should == 2
              @cache.get(@key).should == 2
              $memcache.get(@key).should == nil
            end
            @cache.get(@key, true).to_i.should == 2
            $memcache.get(@key, true).to_i.should == 2
          end

          it "returns nil if there is no key already at that value" do
            @cache.transaction do
              @cache.incr(@key).should == nil
            end
          end

        end

        describe '#decr' do
          it "works" do
            @cache.set(@key, 0)
            @cache.incr(@key)
            @cache.transaction do
              @cache.decr(@key).should == 0
            end
          end

          it "is buffered" do
            @cache.transaction do
              @cache.set(@key, 0)
              @cache.incr(@key, 3)
              @cache.decr(@key, 2).should == 1
              @cache.get(@key, true).to_i.should == 1
              $memcache.get(@key).should == nil
            end
            @cache.get(@key, true).to_i.should == 1
            $memcache.get(@key, true).to_i.should == 1
          end

          it "returns nil if there is no key already at that value" do
            @cache.transaction do
              @cache.decr(@key).should == nil
            end
          end

          it "bottoms out at zero" do
            @cache.transaction do
              @cache.set(@key, 0)
              @cache.incr(@key, 1)
              @cache.get(@key, true).should == 1
              @cache.decr(@key)
              @cache.get(@key, true).should == 0
              @cache.decr(@key)
              @cache.get(@key, true).should == 0
            end
          end
        end
      end

      describe '#get_multi' do
        describe 'when a hit value is the empty array' do
          it 'returns a hash' do
            @cache.transaction do
              @cache.set('key1', @value)
              @cache.set('key2', [])
              @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value, 'key2' => [] }
            end
          end
        end

        describe 'when everything is a hit' do
          it 'returns a hash' do
            @cache.transaction do
              @cache.set('key1', @value)
              @cache.set('key2', @value)
              @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value, 'key2' => @value }
            end
          end
        end

        describe 'when there are misses' do
          it 'only returns results for hits' do
            @cache.transaction do
              @cache.set('key1', @value)
              @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value }
            end
          end
        end
      end

      describe 'Lock Acquisition' do
        it "locks @keys to be written before writing to memcache and release them after" do
          mock($lock).acquire_lock(@key)
          mock($memcache).set(@key, @value)
          mock($lock).release_lock(@key)

          @cache.transaction do
            @cache.set(@key, @value)
          end
        end

        it "does not acquire locks on reads" do
          mock($lock).acquire_lock.never
          mock($lock).release_lock.never

          @cache.transaction do
            @cache.get(@key)
          end
        end

        it "locks @keys in lexically sorted order" do
          keys = ['c', 'a', 'b']
          keys.sort.inject(mock($lock)) do |mock, key|
            mock.acquire_lock(key).then
          end
          keys.each { |key| mock($memcache).set(key, @value) }
          keys.each { |key| mock($lock).release_lock(key) }
          @cache.transaction do
            @cache.set(keys[0], @value)
            @cache.set(keys[1], @value)
            @cache.set(keys[2], @value)
          end
        end

        it "releases locks even if memcache blows up" do
          mock($lock).acquire_lock.with(@key)
          mock($lock).release_lock.with(@key)
          stub($memcache).set(anything, anything) { raise }
          @cache.transaction do
            @cache.set(@key, @value)
          end rescue nil
        end

      end

      describe 'Buffering' do
        it "reading from the cache show uncommitted writes" do
          @cache.get(@key).should == nil
          @cache.transaction do
            @cache.set(@key, @value)
            @cache.get(@key).should == @value
          end
        end

        it "get_multi is buffered" do
          @cache.transaction do
            @cache.set('key1', @value)
            @cache.set('key2', @value)
            @cache.get_multi(['key1', 'key2']).should == { 'key1' => @value, 'key2' => @value }
            $memcache.get_multi(['key1', 'key2']).should == {}
          end
        end

        it "get is memoized" do
          @cache.set(@key, @value)
          @cache.transaction do
            @cache.get(@key).should == @value
            $memcache.set(@key, "new value")
            @cache.get(@key).should == @value
          end
        end

        it "add is buffered" do
          @cache.transaction do
            @cache.add(@key, @value)
            $memcache.get(@key).should == nil
            @cache.get(@key).should == @value
          end
          @cache.get(@key).should == @value
          $memcache.get(@key).should == @value
        end

        describe '#delete' do
          it "within a transaction, delete is isolated" do
            @cache.add(@key, @value)
            @cache.transaction do
              @cache.delete(@key)
              $memcache.add(@key, "another value")
            end
            @cache.get(@key).should == nil
            $memcache.get(@key).should == nil
          end

          it "within a transaction, delete is buffered" do
            @cache.set(@key, @value)
            @cache.transaction do
              @cache.delete(@key)
              $memcache.get(@key).should == @value
              @cache.get(@key).should == nil
            end
            @cache.get(@key).should == nil
            $memcache.get(@key).should == nil
          end
        end
      end

      describe '#incr' do
        it "increment be atomic" do
          @cache.set(@key, 0)
          @cache.transaction do
            @cache.incr(@key)
            $memcache.incr(@key)
          end
          @cache.get(@key, true).to_i.should == 2
          $memcache.get(@key, true).to_i.should == 2
        end

        it "interleaved, etc. increments and sets be ordered" do
          @cache.set(@key, 0)
          @cache.transaction do
            @cache.incr(@key)
            @cache.incr(@key)
            @cache.set(@key, 0)
            @cache.incr(@key)
            @cache.incr(@key)
          end
          @cache.get(@key, true).to_i.should == 2
          $memcache.get(@key, true).to_i.should == 2
        end
      end

      describe '#decr' do
        it "decrement be atomic" do
          @cache.set(@key, 0)
          @cache.incr(@key, 3)
          @cache.transaction do
            @cache.decr(@key)
            $memcache.decr(@key)
          end
          @cache.get(@key, true).to_i.should == 1
          $memcache.get(@key, true).to_i.should == 1
        end
      end

      it "retains the value in the transactional cache after committing the transaction" do
        @cache.get(@key).should == nil
        @cache.transaction do
          @cache.set(@key, @value)
        end
        @cache.get(@key).should == @value
      end

      describe 'when reading from the memcache' do
        it "does NOT show uncommitted writes" do
          @cache.transaction do
            $memcache.get(@key).should == nil
            @cache.set(@key, @value)
            $memcache.get(@key).should == nil
          end
        end
      end
    end

    describe 'Exception Handling' do

      it "re-raises exceptions thrown by memcache" do
        stub($memcache).set(anything, anything) { raise }
        lambda do
          @cache.transaction do
            @cache.set(@key, @value)
          end
        end.should raise_error
      end

      it "rolls back transaction cleanly if an exception is raised" do
        $memcache.get(@key).should == nil
        @cache.get(@key).should == nil
        @cache.transaction do
          @cache.set(@key, @value)
          raise
        end rescue nil
        @cache.get(@key).should == nil
        $memcache.get(@key).should == nil
      end

      it "does not acquire locks if transaction is rolled back" do
        mock($lock).acquire_lock.never
        mock($lock).release_lock.never

        @cache.transaction do
          @cache.set(@key, value)
          raise
        end rescue nil
      end
    end

    describe 'Nested Transactions' do
      it "delegate unsupported messages back to the real cache" do
        @cache.transaction do
          @cache.transaction do
            @cache.transaction do
              mock($memcache).foo(:bar)
              @cache.foo(:bar)
            end
          end
        end
      end

      it "makes newly set keys only be visible within the transaction in which they were set" do
        @cache.transaction do
          @cache.set('key1', @value)
          @cache.transaction do
            @cache.get('key1').should == @value
            @cache.set('key2', @value)
            @cache.transaction do
              @cache.get('key1').should == @value
              @cache.get('key2').should == @value
              @cache.set('key3', @value)
            end
          end
          @cache.get('key1').should == @value
          @cache.get('key2').should == @value
          @cache.get('key3').should == @value
        end
        @cache.get('key1').should == @value
        @cache.get('key2').should == @value
        @cache.get('key3').should == @value
      end

      it "not write any values to memcache until the outermost transaction commits" do
        @cache.transaction do
          @cache.set('key1', @value)
          @cache.transaction do
            @cache.set('key2', @value)
            $memcache.get('key1').should == nil
            $memcache.get('key2').should == nil
          end
          $memcache.get('key1').should == nil
          $memcache.get('key2').should == nil
        end
        $memcache.get('key1').should == @value
        $memcache.get('key2').should == @value
      end

      it "acquire locks in lexical order for all keys" do
        keys = ['c', 'a', 'b']
        keys.sort.inject(mock($lock)) do |mock, key|
          mock.acquire_lock(key).then
        end
        keys.each { |key| mock($memcache).set(key, @value) }
        keys.each { |key| mock($lock).release_lock(key) }
        @cache.transaction do
          @cache.set(keys[0], @value)
          @cache.transaction do
            @cache.set(keys[1], @value)
            @cache.transaction do
              @cache.set(keys[2], @value)
            end
          end
        end
      end

      it "reads through the real memcache if key has not been written to in a transaction" do
        $memcache.set(@key, @value)
        @cache.transaction do
          @cache.transaction do
            @cache.transaction do
              @cache.get(@key).should == @value
            end
          end
        end
        @cache.get(@key).should == @value
      end

      describe 'Error Handling' do
        it "releases locks even if memcache blows up" do
          mock($lock).acquire_lock(@key)
          mock($lock).release_lock(@key)
          stub($memcache).set(anything, anything) { raise }
          @cache.transaction do
            @cache.transaction do
              @cache.transaction do
                @cache.set(@key, @value)
              end
            end
          end rescue nil
        end

        it "re-raise exceptions thrown by memcache" do
          stub($memcache).set(anything, anything) { raise }
          lambda do
            @cache.transaction do
              @cache.transaction do
                @cache.transaction do
                  @cache.set(@key, @value)
                end
              end
            end
          end.should raise_error
        end

        it "rollback transaction cleanly if an exception is raised" do
          $memcache.get(@key).should == nil
          @cache.get(@key).should == nil
          @cache.transaction do
            @cache.transaction do
              @cache.set(@key, @value)
              raise
            end
          end rescue nil
          @cache.get(@key).should == nil
          $memcache.get(@key).should == nil
        end

        it "not acquire locks if transaction is rolled back" do
          mock($lock).acquire_lock.never
          mock($lock).release_lock.never

          @cache.transaction do
            @cache.transaction do
              @cache.set(@key, @value)
              raise
            end
          end rescue nil
        end

        it "support rollbacks" do
          @cache.transaction do
            @cache.set('key1', @value)
            @cache.transaction do
              @cache.get('key1').should == @value
              @cache.set('key2', @value)
              raise
            end rescue nil
            @cache.get('key1').should == @value
            @cache.get('key2').should == nil
          end
          $memcache.get('key1').should == @value
          $memcache.get('key2').should == nil
        end
      end
    end
  end
end
