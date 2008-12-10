require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe Finders do
    describe 'Calculations' do
      describe 'when the cache is populated' do
        before do
          @stories = [Story.create!(:title => @title = 'asdf'), Story.create!(:title => @title)]
        end

        describe '#count(:all, :conditions => ...)' do
          it "does not use the database" do
            Story.count(:all, :conditions => { :title => @title }).should == @stories.size
          end
        end

        describe '#count(:column, :conditions => ...)' do
          it "uses the database, not the cache" do
            mock(Story).get.never
            Story.count(:title, :conditions => { :title => @title }).should == @stories.size
          end
        end

        describe '#count(:all, :distinct => ..., :select => ...)' do
          it 'uses the database, not the cache' do
            mock(Story).get.never
            Story.count(:all, :distinct => true, :select => :title, :conditions => { :title => @title }).should == @stories.collect(&:title).uniq.size
          end
        end

        describe 'association proxies' do
          describe '#count(:all, :conditions => ...)' do
            it 'does not use the database' do
              story = Story.create!
              characters = [story.characters.create!(:name => name = 'name'), story.characters.create!(:name => name)]
              mock(Story.connection).execute.never
              story.characters.count(:all, :conditions => { :name => name }).should == characters.size
            end
          end
        end
      end

      describe 'when the cache is not populated' do
        describe '#count(:all, ...)' do
          describe '#count(:all)' do
            it 'uses the database, not the cache' do
              mock(Story).get.never
              Story.count
            end
          end

          describe '#count(:all, :conditions => ...)' do
            before do
              Story.create!(:title => @title = 'title')
              $memcache.flush_all
            end

            it "populates the count correctly" do
              Story.count(:all, :conditions => { :title => @title }).should == 1
              Story.fetch("title/#{@title}/count", :raw => true).should =~ /\s*1\s*/
            end
          end
        end
      end
    end
  end
end
