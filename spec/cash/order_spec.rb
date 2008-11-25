require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe 'Ordering' do
    before :suite do
      FairyTale = Class.new(Story)
    end

    describe '#create!' do
      describe 'the records are written-through in sorted order', :shared => true do
        describe 'when there are not already records matching the index' do
          it 'initializes the index' do
            fairy_tale = FairyTale.create!(:title => 'title')
            FairyTale.get("title/#{fairy_tale.title}").should == [fairy_tale.id]
          end
        end

        describe 'when there are already records matching the index' do
          before do
            @fairy_tale1 = FairyTale.create!(:title => 'title')
            FairyTale.get("title/#{@fairy_tale1.title}").should == sorted_and_serialized_records(@fairy_tale1)
          end

          describe 'when the index is populated' do
            it 'appends to the index' do
              fairy_tale2 = FairyTale.create!(:title => @fairy_tale1.title)
              FairyTale.get("title/#{@fairy_tale1.title}").should == sorted_and_serialized_records(@fairy_tale1, fairy_tale2)
            end
          end

          describe 'when the index is not populated' do
            before do
              $memcache.flush_all
            end

            it 'initializes the index' do
              fairy_tale2 = FairyTale.create!(:title => @fairy_tale1.title)
              FairyTale.get("title/#{@fairy_tale1.title}").should == sorted_and_serialized_records(@fairy_tale1, fairy_tale2)
            end
          end
        end
      end

      describe 'when the order is ascending' do
        it_should_behave_like 'the records are written-through in sorted order'

        before :all do
          FairyTale.index :title, :order => :asc
        end

        def sorted_and_serialized_records(*records)
          records.collect(&:id).sort
        end
      end

      describe 'when the order is descending' do
        it_should_behave_like 'the records are written-through in sorted order'

        before :all do
          FairyTale.index :title, :order => :desc
        end

        def sorted_and_serialized_records(*records)
          records.collect(&:id).sort.reverse
        end
      end
    end

    describe "#find(..., :order => ...)" do
      before :each do
        @fairy_tales = [FairyTale.create!(:title => @title = 'title'), FairyTale.create!(:title => @title)]
      end

      describe 'when the order is ascending' do
        before :all do
          FairyTale.index :title, :order => :asc
        end

        describe "#find(..., :order => 'id ASC')" do
          describe 'when the cache is populated' do
            it 'does not use the database' do
              mock(FairyTale.connection).execute.never
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id ASC').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`id`').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'stories.id').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`stories`.id').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`stories`.`id`').should == @fairy_tales
            end
          end

          describe 'when the cache is not populated' do
            it 'populates the cache' do
              $memcache.flush_all
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id ASC').should == @fairy_tales
              FairyTale.get("title/#{@title}").should == @fairy_tales.collect(&:id)
            end
          end
        end

        describe "#find(..., :order => 'id DESC')" do
          describe 'when the cache is populated' do
            it 'uses the database, not the cache' do
              mock(FairyTale).get.never
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id DESC').should == @fairy_tales.reverse
            end
          end

          describe 'when the cache is not populated' do
            it 'does not populate the cache' do
              $memcache.flush_all
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id DESC').should == @fairy_tales.reverse
              FairyTale.get("title/#{@title}").should be_nil
            end
          end
        end
      end

      describe 'when the order is descending' do
        before :all do
          FairyTale.index :title, :order => :desc
        end

        describe "#find(..., :order => 'id DESC')" do
          describe 'when the cache is populated' do
            it 'does not use the database' do
              mock(FairyTale.connection).execute.never
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id DESC').should == @fairy_tales.reverse
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id DESC').should == @fairy_tales.reverse
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`id` DESC').should == @fairy_tales.reverse
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'stories.id DESC').should == @fairy_tales.reverse
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`stories`.id DESC').should == @fairy_tales.reverse
              FairyTale.find(:all, :conditions => { :title => @title }, :order => '`stories`.`id` DESC').should == @fairy_tales.reverse
            end
          end

          describe 'when the cache is not populated' do
            it 'populates the cache' do
              $memcache.flush_all
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id DESC')
              FairyTale.get("title/#{@title}").should == @fairy_tales.collect(&:id).reverse
            end
          end
        end

        describe "#find(..., :order => 'id ASC')" do
          describe 'when the cache is populated' do
            it 'uses the database, not the cache' do
              mock(FairyTale).get.never
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id ASC').should == @fairy_tales
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id').should == @fairy_tales
            end
          end

          describe 'when the cache is not populated' do
            it 'does not populate the cache' do
              $memcache.flush_all
              FairyTale.find(:all, :conditions => { :title => @title }, :order => 'id ASC').should == @fairy_tales
              FairyTale.get("title/#{@title}").should be_nil
            end
          end
        end
      end
    end
  end
end
