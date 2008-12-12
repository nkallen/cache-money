require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe Accessor do
    describe '#fetch' do
      describe '#fetch("...")' do
        describe 'when there is a cache miss' do
          it 'returns nil' do
            Story.fetch("yabba").should be_nil
          end
        end

        describe 'when there is a cache hit' do
          it 'returns the value of the cache' do
            Story.set("yabba", "dabba")
            Story.fetch("yabba").should == "dabba"
          end
        end
      end

      describe '#fetch([...])', :shared => true do
        describe 'when there is a total cache miss' do
          it 'yields the keys to the block' do
            Story.fetch(["yabba", "dabba"]) { |*missing_ids| ["doo", "doo"] }.should == {
              "Story:1/yabba" => "doo",
              "Story:1/dabba" => "doo"
            }
          end
        end

        describe 'when there is a partial cache miss' do
          it 'yields just the missing ids to the block' do
            Story.set("yabba", "dabba")
            Story.fetch(["yabba", "dabba"]) { |*missing_ids| "doo" }.should == {
              "Story:1/yabba" => "dabba",
              "Story:1/dabba" => "doo"
            }
          end
        end
      end
    end

    describe '#get' do
      describe '#get("...")' do
        describe 'when there is a cache miss' do
          it 'returns the value of the block' do
            Story.get("yabba") { "dabba" }.should == "dabba"
          end

          it 'adds to the cache' do
            Story.get("yabba") { "dabba" }
            Story.get("yabba").should == "dabba"
          end
        end

        describe 'when there is a cache hit' do
          before do
            Story.set("yabba", "dabba")
          end

          it 'returns the value of the cache' do
            Story.get("yabba") { "doo" }.should == "dabba"
          end

          it 'does nothing to the cache' do
            Story.get("yabba") { "doo" }
            Story.get("yabba").should == "dabba"
          end
        end
      end

      describe '#get([...])' do
        it_should_behave_like "#fetch([...])"
      end
    end

    describe '#incr' do
      describe 'when there is a cache hit' do
        before do
          Story.set("count", 0)
        end

        it 'increments the value of the cache' do
          Story.incr("count", 2)
          Story.get("count", :raw => true).should =~ /2/
        end

        it 'returns the new cache value' do
          Story.incr("count", 2).should == 2
        end
      end

      describe 'when there is a cache miss' do
        it 'initializes the value of the cache to the value of the block' do
          Story.incr("count", 1) { 5 }
          Story.get("count", :raw => true).should =~ /5/
        end

        it 'returns the new cache value' do
          Story.incr("count", 1) { 2 }.should == 2
        end
      end
    end

    describe '#add' do
      describe 'when the value already exists' do
        it 'yields to the block' do
          Story.set("count", 1)
          Story.add("count", 1) { "yield me" }.should == "yield me"
        end
      end

      describe 'when the value does not already exist' do
        it 'adds the key to the cache' do
          Story.add("count", 1)
          Story.get("count").should == 1
        end
      end
    end

    describe '#decr' do
      describe 'when there is a cache hit' do
        before do
          Story.incr("count", 1) { 10 }
        end

        it 'decrements the value of the cache' do
          Story.decr("count", 2)
          Story.get("count", :raw => true).should =~ /8/
        end

        it 'returns the new cache value' do
          Story.decr("count", 2).should == 8
        end
      end

      describe 'when there is a cache miss' do
        it 'initializes the value of the cache to the value of the block' do
          Story.decr("count", 1) { 5 }
          Story.get("count", :raw => true).should =~ /5/
        end

        it 'returns the new cache value' do
          Story.decr("count", 1) { 2 }.should == 2
        end
      end
    end

    describe '#cache_key' do
      it 'uses the version number' do
        Story.version 1
        Story.cache_key("foo").should == "Story:1/foo"

        Story.version 2
        Story.cache_key("foo").should == "Story:2/foo"
      end
    end
  end
end
