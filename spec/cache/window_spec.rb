require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe 'Windows' do
    LIMIT, BUFFER = 5, 2
    
    before :suite do
      Fable = Class.new(Story)
      Fable.index :title, :limit => LIMIT, :buffer => BUFFER
    end
    
    describe '#find(...)' do
      before do
        @fables = []
        10.times { @fables << Fable.create!(:title => @title = 'title') }
      end
      
      describe 'when the cache is populated' do
        describe "#find(:all, :conditions => ...)" do
          it "uses the database, not the cache" do
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }).should == @fables
          end
        end

        describe "#find(:all, :conditions => ..., :limit => ...) and query limit > index limit" do
          it "uses the database, not the cache" do
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => LIMIT + 1).should == @fables[0, LIMIT + 1]
          end
        end
        
        describe "#find(:all, :conditions => ..., :limit => ..., :offset => ...) and query limit + offset > index limit" do
          it "uses the database, not the cache" do
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => 1, :offset => LIMIT).should == @fables[LIMIT, 1]
          end
        end

        describe "#find(:all, :conditions => ..., :limit => ...) and query limit <= index limit" do
          it "does not use the database" do
            mock(Fable.connection).execute.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => LIMIT - 1).should == @fables[0, LIMIT - 1]
          end
        end
      end
      
      describe 'when the cache is not populated' do
        before do
          $memcache.flush_all
        end
        
        describe "#find(:all, :conditions => ..., :limit => ...) and query limit <= index limit" do
          describe 'when there are fewer than limit + buffer items' do
            it "populates the cache with all items" do
              Fable.find(:all, :limit => deleted = @fables.size - LIMIT - BUFFER + 1).collect(&:destroy)
              $memcache.flush_all
              Fable.find(:all, :conditions => { :title => @title }, :limit => LIMIT).should == @fables[deleted, LIMIT]
              Fable.get("title/#{@title}").should == @fables[deleted, @fables.size - deleted].collect(&:id)
            end
          end
          
          describe 'when there are more than limit + buffer items' do
            it "populates the cache with limit + buffer items" do
              Fable.find(:all, :conditions => { :title => @title }, :limit => 5).should == @fables[0, 5]
              Fable.get("title/#{@title}").should == @fables[0, LIMIT + BUFFER].collect(&:id)
            end
          end
        end
      end
    end
    
    describe '#create!' do
      describe 'when the cache is populated' do
        describe 'when the count is > limit + buffer items' do
          it 'truncates when the count is more than limit + buffer' do
            fables, title = [], 'title'
            (LIMIT + BUFFER).times { fables << Fable.create!(:title => title) }
            Fable.get("title/#{title}").should == fables.collect(&:id)
            Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end

        describe 'when the count is < limit + buffer items' do
          it 'appends to the list' do
            fables, title = [], 'title'
            (LIMIT + BUFFER - 1).times { fables << Fable.create!(:title => title) }
            Fable.get("title/#{title}").should == fables.collect(&:id)
            fables << Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end
      end
      
      describe 'when the cache is not populated' do
        describe 'when the count is > limit + buffer items' do
          it 'truncates when the count is more than limit + buffer' do
            fables, title = [], 'title'
            (LIMIT + BUFFER).times { fables << Fable.create!(:title => title) }
            $memcache.flush_all
            Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end

        describe 'when the count is < limit + buffer items' do
          it 'appends to the list' do
            fables, title = [], 'title'
            (LIMIT + BUFFER - 1).times { fables << Fable.create!(:title => title) }
            $memcache.flush_all
            fables << Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end
      end
    end
    
    describe '#destroy!' do
      describe 'when the cache is populated' do
        describe 'when the index size is <= limit of items' do
          describe 'when count of records in the database <= limit of items' do
            it 'deletes from the list' do
              fables, title = [], 'title'
              LIMIT.times { fables << Fable.create!(:title => title) }
              mock(Fable.connection).select.never
              fables.shift.destroy
              Fable.get("title/#{title}").should == fables.collect(&:id)
            end
          end
          
          describe 'when the count of records in the database <= limit of items' do
            it 'refreshes the list' do
              fables, title = [], 'title'
              (LIMIT + BUFFER + 1).times { fables << Fable.create!(:title => title) }
              (BUFFER + 1).times { fables.shift.destroy }
              Fable.get("title/#{title}").should == fables.collect(&:id)              
            end
          end
        end

        describe 'when the count is > limit of items' do
          it 'deletes from the list' do
            fables, title = [], 'title'
            LIMIT.times { fables << Fable.create!(:title => title) }
            fables.pop.destroy
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end
      end
    end
  end
end