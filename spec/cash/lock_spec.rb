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

      it "does not block on recursive lock acquisition" do
        $lock.synchronize('lock_key') do
          lambda { $lock.synchronize('lock_key') {} }.should_not raise_error
        end
      end
    end

    describe '#acquire_lock' do
      it "creates a lock at a given cache key" do
        $memcache.get("lock/lock_key").should == nil
        $lock.acquire_lock("lock_key")
        $memcache.get("lock/lock_key").should_not == nil
      end

      describe 'when given a timeout for the lock' do
        it "correctly sets timeout on memcache entries" do
          mock($memcache).add('lock/lock_key', Process.pid, timeout = 10) { true }
          $lock.acquire_lock('lock_key', timeout)
        end
      end

      describe 'when to processes contend for a lock' do
        it "prevents two processes from acquiring the same lock at the same time" do
          $lock.acquire_lock('lock_key')
          as_another_process do
            stub($lock).exponential_sleep
            lambda { $lock.acquire_lock('lock_key') }.should raise_error
          end
        end
        
        describe 'when given a number of times to retry' do
          it "retries specified number of times" do
            $lock.acquire_lock('lock_key')
            as_another_process do
              mock($memcache).add("lock/lock_key", Process.pid, timeout = 10) { false }.times(retries = 3)
              stub($lock).exponential_sleep
              lambda { $lock.acquire_lock('lock_key', timeout, retries) }.should raise_error
            end
          end
        end
        
        describe 'when given an initial wait' do
          it 'sleeps exponentially starting with the initial wait' do
            mock($lock).sleep(initial_wait = 0.123)
            mock($lock).sleep(2 * initial_wait)
            mock($lock).sleep(4 * initial_wait)
            mock($lock).sleep(8 * initial_wait)
            $lock.acquire_lock('lock_key')
            as_another_process do
              lambda { $lock.acquire_lock('lock_key', Lock::DEFAULT_EXPIRY, Lock::DEFAULT_RETRY, initial_wait) }.should raise_error
            end            
          end
        end

        def as_another_process
          current_pid = Process.pid
          stub(Process).pid { current_pid + 1 }
          yield
        end
      end
    end

    describe '#release_lock' do
      it "deletes the lock for a given cache key" do
        $memcache.get("lock/lock_key").should == nil
        $lock.acquire_lock("lock_key")
        $memcache.get("lock/lock_key").should_not == nil
        $lock.release_lock("lock_key")
        $memcache.get("lock/lock_key").should == nil
      end
    end
  end
end