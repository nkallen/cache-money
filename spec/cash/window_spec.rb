require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
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
              $memcache.flush_all
              Fable.find(:all, :conditions => { :title => @title }, :limit => 5).should == @fables[0, 5]
              Fable.get("title/#{@title}").should == @fables[0, LIMIT + BUFFER].collect(&:id)
            end
          end
        end
      end
    end

    describe '#create!' do
      describe 'when the cache is populated' do
        describe 'when the count of records in the database is > limit + buffer items' do
          it 'truncates' do
            fables, title = [], 'title'
            (LIMIT + BUFFER).times { fables << Fable.create!(:title => title) }
            Fable.get("title/#{title}").should == fables.collect(&:id)
            Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end

        describe 'when the count of records in the database is < limit + buffer items' do
          it 'appends to the list' do
            fables, title = [], 'title'
            (LIMIT + BUFFER - 1).times { fables << Fable.create!(:title => title) }
            Fable.get("title/#{title}").should == fables.collect(&:id)
            fable = Fable.create!(:title => title)
            Fable.get("title/#{title}").should == (fables << fable).collect(&:id)
          end
        end
      end

      describe 'when the cache is not populated' do
        describe 'when the count of records in the database is > limit + buffer items' do
          it 'truncates the index' do
            fables, title = [], 'title'
            (LIMIT + BUFFER).times { fables << Fable.create!(:title => title) }
            $memcache.flush_all
            Fable.create!(:title => title)
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end

        describe 'when the count of records in the database is < limit + buffer items' do
          it 'appends to the list' do
            fables, title = [], 'title'
            (LIMIT + BUFFER - 1).times { fables << Fable.create!(:title => title) }
            $memcache.flush_all
            fable = Fable.create!(:title => title)
            Fable.get("title/#{title}").should == (fables << fable).collect(&:id)
          end
        end
      end
    end

    describe '#destroy' do
      describe 'when the cache is populated' do
        describe 'when the index size is <= limit of items' do
          describe 'when the count of records in the database is <= limit of items' do
            it 'deletes from the list without refreshing from the database' do
              fables, title = [], 'title'
              LIMIT.times { fables << Fable.create!(:title => title) }
              Fable.get("title/#{title}").size.should <= LIMIT

              mock(Fable.connection).select.never
              fables.shift.destroy
              Fable.get("title/#{title}").should == fables.collect(&:id)
            end
          end

          describe 'when the count of records in the database is >= limit of items' do
            it 'refreshes the list (from the database)' do
              fables, title = [], 'title'
              (LIMIT + BUFFER + 1).times { fables << Fable.create!(:title => title) }
              BUFFER.times { fables.shift.destroy }
              Fable.get("title/#{title}").size.should == LIMIT

              fables.shift.destroy
              Fable.get("title/#{title}").should == fables.collect(&:id)

            end
          end
        end

        describe 'when the index size is > limit of items' do
          it 'deletes from the list' do
            fables, title = [], 'title'
            (LIMIT + 1).times { fables << Fable.create!(:title => title) }
            Fable.get("title/#{title}").size.should > LIMIT

            fables.shift.destroy
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end
        end
      end

      describe 'when the cache is not populated' do
        describe 'when count of records in the database is <= limit of items' do
          it 'deletes from the index' do
            fables, title = [], 'title'
            LIMIT.times { fables << Fable.create!(:title => title) }
            $memcache.flush_all

            fables.shift.destroy
            Fable.get("title/#{title}").should == fables.collect(&:id)
          end

          describe 'when the count of records in the database is between limit and limit + buffer items' do
            it 'populates the index' do
              fables, title = [], 'title'
              (LIMIT + BUFFER + 1).times { fables << Fable.create!(:title => title) }
              BUFFER.times { fables.shift.destroy }
              $memcache.flush_all

              fables.shift.destroy
              Fable.get("title/#{title}").should == fables.collect(&:id)

            end
          end

          describe 'when the count of records in the database is > limit + buffer items' do
            it 'populates the index with limit + buffer items' do
              fables, title = [], 'title'
              (LIMIT + BUFFER + 2).times { fables << Fable.create!(:title => title) }
              $memcache.flush_all

              fables.shift.destroy
              Fable.get("title/#{title}").should == fables[0, LIMIT + BUFFER].collect(&:id)
            end
          end
        end
      end
    end
  end
end
