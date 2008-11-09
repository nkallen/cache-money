require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe WriteThrough do

    before :suite do
      Story = Class.new(ActiveRecord::Base)
      Character = Class.new(ActiveRecord::Base)
      Story.index :on => [:id, :title, [:id, :title]], :repository => Transactional.new($memcache, $lock)

      Epic = Class.new(Story)
      Oral = Class.new(Epic)
      Story.has_many :characters
    end

    before :each do
      Story.delete_all
    end

    describe 'ClassMethods' do
      describe 'after create' do
        it "inserts all indexed attributes into the cache" do
          story = Story.create!(:title => "I am delicious")
          Story.get("title:#{story.title}").should == [story.id]
          Story.get("id:#{story.id}").should == [story]
        end

        it "inserts multiple objects into the same cache key" do
          story1 = Story.create!(:title => "I am delicious")
          story2 = Story.create!(:title => "I am delicious")
          Story.get("title:#{story1.title}").should == [story1.id, story2.id]
        end

        it "does not write through the cache on non-indexed attributes" do
          story = Story.create!(:title => "Story 1", :subtitle => "Subtitle")
          Story.get("subtitle:#{story.subtitle}").should == nil
        end

        it "indexes on combinations of attributes" do
          story = Story.create(:title => "Sam")
          Story.get("id:#{story.id}:title:#{story.title}").should == [story.id]
        end

        it "does not cache associations" do
          story = Story.new(:title => 'I am lugubrious')
          story.characters.build(:name => 'How am I holy?')
          story.save!
          Story.get("id:#{story.id}").first.characters.loaded?.should_not be
        end

        describe 'when the value is nil' do
          it "does not write through the cache on indexed attributes" do
            story = Story.create!(:title => nil)
            Story.get("title:").should == nil
          end
        end
      end

      describe 'after update' do
        it "overwrites the primary cache" do
          story = Story.create!(:title => "I am delicious")
          Story.get(cache_key = "id:#{story.id}").first.title.should == "I am delicious"
          story.update_attributes(:title => "I am fabulous")
          Story.get(cache_key).first.title.should == "I am fabulous"
        end

        it "populates empty caches" do
          story = Story.create!(:title => "I am delicious")
          Story.cache_repository.flush_all
          story.update_attributes(:title => "I am fabulous")
          Story.get("title:#{story.title}").should == [story.id]
        end

        it "removes from the affected index caches on update" do
          story = Story.create!(:title => "I am delicious")
          Story.get(cache_key = "title:#{story.title}").should == [story.id]
          story.update_attributes(:title => "I am fabulous")
          Story.get(cache_key).should == []
        end

      end

      describe 'after destroy' do
        it "removes from the primary cache" do
          story = Story.create!(:title => "I am delicious")
          Story.get(cache_key = "id:#{story.id}").should == [story]
          story.destroy
          Story.get(cache_key).should == []
        end

        it "removes from the the cache on keys matching the original values of attributes" do
          story = Story.create!(:title => "I am delicious")
          Story.get(cache_key = "title:#{story.title}").should == [story.id]
          story.title = "I am not delicious"
          story.destroy
          Story.get(cache_key).should == []
        end

        describe 'when there are multiple items in the index' do
          it "only removes one item from the affected indices, not all of them" do
            story1 = Story.create!(:title => "I am delicious")
            story2 = Story.create!(:title => "I am delicious")
            Story.get(cache_key = "title:#{story1.title}").should == [story1.id, story2.id]
            story1.destroy
            Story.get(cache_key).should == [story2.id]
          end
        end

        describe 'when the cache is not yet populated' do
          it "populates the cache with data, if the cache is not yet populated" do
            story1 = Story.create!(:title => "I am delicious")
            story2 = Story.create!(:title => "I am delicious")
            Story.cache_repository.flush_all
            Story.get(cache_key = "title:#{story1.title}").should == nil
            story1.destroy
            Story.get(cache_key).should == [story2.id]
          end
        end

        describe 'when the value is nil' do
          it "should not delete through the cache on indexed attributes when the value is nil" do
            story = Story.create!(:title => nil)
            story.destroy
            Story.get("title:").should == nil
          end
        end
      end
    end

    describe 'Instance Methods' do
      describe "#expire_cache" do
        it "expires cache entries at keys where the object is indexed" do
          story = Story.create!(:title => "some stuff")
          story.expire_cache
          Story.get("id:#{story.id}").should == nil
          Story.get("title:#{story.title}").should == nil
        end
      end
    end

    describe "Locking" do
      it "acquires and releases locks, in order, for all indices to be written" do
        story = Story.create!(:title => original_title = "original title")
        story.title = tentative_title = "tentative title"
        keys = ["id:#{story.id}", "title:#{original_title}", "title:#{story.title}", "id:#{story.id}:title:#{original_title}", "id:#{story.id}:title:#{tentative_title}"]

        locks_should_be_acquired_and_released_in_order($lock, keys)
        story.save!
      end

      it "acquires and releases locks on destroy" do
        story = Story.create!(:title => "title")
        keys = ["id:#{story.id}", "title:#{story.title}", "id:#{story.id}:title:#{story.title}"]

        locks_should_be_acquired_and_released_in_order($lock, keys)
        story.destroy
      end

      def locks_should_be_acquired_and_released_in_order(lock, keys)
        mock = keys.sort!.inject(mock = mock($lock)) do |mock, key|
          mock.acquire_lock.with(Story.cache_key(key)).then
        end
        keys.inject(mock) do |mock, key|
          mock.release_lock.with(Story.cache_key(key)).then
        end
      end
    end

    describe "STI" do
      it "always writes to the base-class cache" do
        story = Story.create!(:title => title = 'foo')
        feature = Epic.create!(:title => title)
        detail = Oral.create!(:title => title)
        Story.get("title:#{story.title}").should == [story.id, feature.id, detail.id]
      end
    end
  end
end