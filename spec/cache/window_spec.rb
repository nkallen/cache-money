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
            pending
            mock(Fable).get.never
            Fable.find(:all, :conditions => { :title => @title }, :offset => LIMIT + 1).should == @fables[LIMIT..-1]
          end
        end

        describe "#find(:all, :conditions => ..., :limit => ...) and query limit < index limit" do
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
        
        describe "#find(:all, :conditions => ..., :limit => <= index limit)" do
          describe 'when there are fewer than limit + buffer items' do
            it "populates the cache with all items" do
              Fable.find(:all, :conditions => { :title => @title })
              # Fable.get("title/@title").size.should == 
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