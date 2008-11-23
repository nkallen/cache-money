require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe 'Windows' do
    before :suite do
      Fable = Class.new(Story)
      Fable.index :title, :limit => 5, :buffer => 2
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
            Fable.find(:all, :conditions => { :title => @title })
          end
        end

        describe "#find(:all, :conditions => ..., :limit => ...) and query limit > index limit" do
          it "uses the database, not the cache" do
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => 100)
          end
        end
        
        describe "#find(:all, :conditions => ..., :limit => ..., :offset => ...) and query limit + offset > index limit" do
          it "uses the database, not the cache" do
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => 1, :offset => 100)
          end
        end

        describe "#find(:all, :conditions => ..., :limit => ...) and query limit < index limit" do
          it "does not use the database" do
            mock(Fable.connection).execute.never
            Fable.find(:all, :conditions => { :title => @title }, :limit => 2)
          end
        end
      end
      
      describe 'when the cache is not populated' do
        before do
          $memcache.flush_all
        end
        
        describe "#find(:all, :conditions => ..., :limit => <= index limit)" do
          describe 'when there are fewer than limit + buffer items' do
            it "populates the cache with all items" do
              mock(Fable.connection).execute
              Fable.find(:all, :conditions => { :title => @title })
              # Fable.get("title/@title").size.should == 
            end
          end
          
          describe 'when there are more than limit + buffer items' do
            it "populates the cache with limit + buffer items" do
              mock(Fable.connection).execute
              Fable.find(:all, :conditions => { :title => @title })
            end
          end
        end
      end
      
      describe '#create!' do
        describe 'when you have > limit + buffer items' do
          it 'truncates when you have more than limit + buffer' do
          end
        end

        describe 'when you have < limit + buffer items' do
        end
      end
    end    

    describe '#destroy!' do
      describe 'when you have <= limit of items' do
        describe 'when the count is <= limit of items' do
        end

        describe 'when the count > limit of items' do
        end
      end

      describe 'when you have > limit of items' do
      end
    end
  end
end