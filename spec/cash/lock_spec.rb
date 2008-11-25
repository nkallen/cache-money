require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe Lock do
    describe '#synchronize' do
      it "yields the block" do
        block_was_called = false
        $lock.synchronize('lock_key') do
          block_was_called = true
        end
        block_was_called.should == true
      end

      it "acquires the specified lock before the block is run" do
        $memcache.get("lock/lock_key").should == nil
        $lock.synchronize('lock_key') do
           $memcache.get("lock/lock_key").should_not == nil
         end
      end

      it "releases the lock after the block is run" do
        $memcache.get("lock/lock_key").should == nil
        $lock.synchronize('lock_key') {}
        $memcache.get("lock/lock_key").should == nil

      end

      it "releases the lock even if the block raises" do
        $memcache.get("lock/lock_key").should == nil
        $lock.synchronize('lock_key') { raise } rescue nil
        $memcache.get("lock/lock_key").should == nil
      end

      specify "does not block on recursive lock acquisition" do
        $lock.synchronize('lock_key') do
          lambda { $lock.synchronize('lock_key') {} }.should_not raise_error
        end
      end
    end

    describe '#acquire_lock' do
      specify "creates a lock at a given cache key" do
        $memcache.get("lock/lock_key").should == nil
        $lock.acquire_lock("lock_key")
        $memcache.get("lock/lock_key").should_not == nil
      end

      specify "retries specified number of times" do
        $lock.acquire_lock('lock_key')
        as_another_process do
          mock($memcache).add("lock/lock_key", Process.pid, timeout = 10) { "NOT_STORED\r\n" }.times(3)
          stub($lock).exponential_sleep
          lambda { $lock.acquire_lock('lock_key', timeout, 3) }.should raise_error
        end
      end

      specify "correctly sets timeout on memcache entries" do
        mock($memcache).add('lock/lock_key', Process.pid, timeout = 10) { "STORED\r\n" }
        $lock.acquire_lock('lock_key', timeout)
      end

      specify "prevents two processes from acquiring the same lock at the same time" do
        $lock.acquire_lock('lock_key')
        as_another_process do
          lambda { $lock.acquire_lock('lock_key') }.should raise_error
        end
      end

      def as_another_process
        current_pid = Process.pid
        stub(Process).pid { current_pid + 1 }
        yield
      end

    end

    describe '#release_lock' do
      specify "deletes the lock for a given cache key" do
        $memcache.get("lock/lock_key").should == nil
        $lock.acquire_lock("lock_key")
        $memcache.get("lock/lock_key").should_not == nil
        $lock.release_lock("lock_key")
        $memcache.get("lock/lock_key").should == nil
      end
    end
  end
end
