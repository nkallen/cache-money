require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe Finders do
    before :suite do
      Story = Class.new(ActiveRecord::Base)
      Character = Class.new(ActiveRecord::Base)
      Story.has_many :characters
      Story.index :on => [:id, :title, [:id, :title]], :repository => Transactional.new($memcache, $lock)
    end
    
    before :each do
      Story.delete_all
    end

    describe "#find" do
      describe 'when given ids' do
        describe 'when the cache is already populated' do
          it "should handle finds with a single id correctly" do
            story = Story.create!(:title => 'a story')
            Story.find(story.id).should == story
          end
        end

        describe 'when the cache is not populated' do
          it "handles finds with a single id correctly when cache is not already populated" do
            story = Story.create!(:title => 'a story')
            Story.cache_repository.flush_all
            Story.find(story.id).should == story
          end
        end
        
        describe 'when the object is destroyed' do
          it "raises an exception" do
            story = Story.create!(:title => "I am delicious")
            story.destroy
            lambda { Story.find(story.id) }.should raise_error(ActiveRecord::RecordNotFound)
          end
        end

        describe 'when given multiple ids' do
          describe 'when the cache is already populted' do
            it "handles finds with multiple ids correctly" do
              story1 = Story.create!
              story2 = Story.create!
              Story.find(story1.id, story2.id).should == [story1, story2]
            end
          end

          describe 'when the cache is partially populated' do
            it "handles finds with multiple ids correctly" do
              story1 = Story.create!(:title => 'story 1')
              Story.cache_repository.flush_all
              story2 = Story.create!(:title => 'story 2')
              Story.find(story1.id, story2.id).should == [story1, story2]
            end
          end

          describe 'when the cache is not populated' do
            it "should handle finds with multiple ids correctly" do
              story1 = Story.create!
              story2 = Story.create!
              Story.cache_repository.flush_all
              Story.find(story1.id, story2.id).should == [story1, story2]
            end
          end

          describe "when given some nil arguments" do
            it "ignores the nils" do
              story = Story.create!
              Story.find(story.id, nil).should == story
            end
          end
        end

        describe 'when given nonexistend ids' do
          describe 'when given one nonexistent id' do
            it 'raises an error' do
              lambda { Story.find(1) }.should raise_error(ActiveRecord::RecordNotFound)
            end
          end

          describe 'when given multiple nonexistent ids' do
             it "raises an exception" do
              lambda { Story.find(1, 2, 3) }.should raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end
      end
      
      describe 'when given objects that are not arrays' do
        it "should coerce arguments to integers" do
          story = Story.create!
          Story.find(story.id.to_s).should == story
        end
      end

      describe 'when given arrays' do
        describe 'when given an array with valid ids' do
          it "finds the object with that id" do
            story = Story.create!
            Story.find([story.id]).should == [story]
          end
        end

        describe 'when given the empty array' do
          it 'returns the empty array' do
            Story.find([]).should == []
          end
        end

        describe 'when given nonexistent ids' do
          it 'raises an exception' do
            lambda { Story.find([1, 2, 3]) }.should raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
      
      describe 'find(:first, ..., :offset => ...)' do
        it "finds the object in the correct order" do
          story1 = Story.create!(:title => 'title1')
          story2 = Story.create!(:title => story1.title)
          Story.find(:first, :conditions => { :title => story1.title }, :offset => 1).should == story2
        end
      end
      
      describe 'find(:first, :conditions => [])' do
        it 'works' do
          story = Story.create!
          Story.find(:first, :conditions => []).should == story
        end
      end
    end

    describe '#find_by_attr' do
      it 'handles nils' do
        Story.find_by_id(nil).should == nil
      end

      it 'handles non-existent ids' do
        Story.find_by_id(-1).should == nil
      end
    end

    describe '#find_all_by_attr' do
      it "does not blow up when called with bad ids" do
        lambda { Story.find_all_by_id([-1, -2, -3]) }.should_not raise_error
      end
    end

    describe 'Cache Usage' do
      describe 'when the cache is populated' do
        describe '#find' do
          describe 'when given an id' do
            it 'does not use the database' do
              story = Story.create!
              mock(Story.connection).execute.never
              Story.find(story.id).should == story
            end
          end
          
          describe 'find(:first, ...)' do
          
            describe 'find(:first, :conditions => { :id => ?})' do
              it "does not use the database" do
                story = Story.create!
                mock(Story.connection).execute.never
                Story.find(:first, :conditions => { :id => story.id }).should == story
              end
            end
          
            describe "find(:first, :conditions => 'id = ?')" do
              it "does not use the database" do
                story = Story.create!
                mock(Story.connection).execute.never
                Story.find(:first, :conditions => "id = #{story.id}").should == story
                Story.find(:first, :conditions => "`stories`.id = #{story.id}").should == story
                Story.find(:first, :conditions => "`stories`.`id` = #{story.id}").should == story
              end
            end
          
            describe 'find(:first, :readonly => false) and any other options other than conditions are nil' do
              it "does not use the database" do
                story = Story.create!
                mock(Story.connection).execute.never
                Story.find(:first, :conditions => { :id => story.id }, :readonly => false, :limit => nil, :offset => nil, :joins => nil, :include => nil).should == story
              end
            end
          
            describe 'find(:first, :readonly => true)' do
              it "uses the database, not the cache" do
                story = Story.create!
                mock(Story).fetch_cache.never
                Story.find(:first, :conditions => { :id => story.id }, :readonly => true).should == story
              end
            end
          
            describe 'find(:first, :join => ...) or find(..., :include => ...)'
              it "uses the database, not the cache" do
                story = Story.create!
                mock(Story).fetch_cache.never
                Story.find(:first, :conditions => { :id => story.id }, :joins => 'AS stories').should == story
                Story.find(:first, :conditions => { :id => story.id }, :include => :characters).should == story
              end
            end
          
            describe 'find(:first)' do
              it 'uses the database, not the cache' do
                mock(Story).fetch_cache.never
                Story.find(:first)
              end
            end

            describe 'find(:first, :conditions => { :id => ?, :other ...})' do
              it 'uses the database, not the cache' do
                story = Story.create!
                mock(Story).fetch_cache.never
                Story.find(:first, :conditions => { :id => story.id, :title => story.title }).should == story
              end
            end
          
            describe 'find(:first, :conditions => "...")' do
              describe 'on unindexed attributes' do
                it 'uses the database, not the cache' do
                  story = Story.create!
                  mock(Story).fetch_cache.never
                  Story.find(:first, :conditions => "type IS NULL")
                end
              end
            
              describe 'on indexed attributes' do
                describe 'when the attributes are integers' do
                  it 'does not use the database' do
                    story = Story.create!
                    mock(Story.connection).execute.never
                    Story.find(:first, :conditions => "`stories`.id = #{story.id}") \
                      .should == story
                  end
                end
              
                describe 'when the attribtues have non-integers' do
                  it 'uses the database, not the cache' do
                    pending "the regexp is too limited too handle this case"
                    story = Story.create(:title => "title")
                    mock(Story.connection).execute.never
                    Story.find(:first, :conditions => "`stories`.title = '#{story.title }'") \
                      .should == story
                  end
                end
              end
            
              describe 'find(:first, :conditions => [...])' do
                describe 'with one indexed attributes' do
                  it 'does not use the database' do
                    story = Story.create!
                    mock(Story.connection).execute.never
                    Story.find(:first, :conditions => ['id = ?', story.id]).should == story
                  end
                end
              
                describe 'with two attributes that match a combo-index' do
                  it 'does not use the database' do
                    story = Story.create!(:title => 'title')
                    mock(Story.connection).execute.never
                    Story.find(:first, :conditions => ['id = ? AND title = ?', story.id, story.title]).should == story
                  end
                end
              end
            end
          
            describe 'find(:first, :conditions => {...})' do
              it "does not use the database" do
                story = Story.create(:title => "Sam")
                mock(Story.connection).execute.never
                Story.find(:first, :conditions => { :id => story.id, :title => story.title }).should == story
              end
            
              describe 'regardless of hash order' do
                it 'does not use the database' do
                  story = Story.create(:title => "Sam")
                  mock(Story.connection).execute.never
                  Story.find(:first, :conditions => { :id => story.id, :title => story.title }).should == story
                  Story.find(:first, :conditions => { :title => story.title, :id => story.id }).should == story
                end
              end
            end
          end
        
          describe 'when there is a with_scope' do
            describe 'when the with_scope has conditions' do
              describe 'when the scope conditions is a string' do
                it "uses the database, not the cache" do
                  story = Story.create!
                  mock(Story).fetch_cache.never
                  Story.send :with_scope, :find => { :conditions => 'type IS NULL'} do
                    Story.find(:first, :conditions => { :id => story.id })
                  end
                end
              end
            
              describe 'when the find conditions is a string' do
                it "uses the database, not the cache" do
                  story = Story.create!
                  mock(Story).fetch_cache.never
                  Story.send :with_scope, :find => { :conditions => { :id => story.id }} do
                    Story.find(:first, :conditions => "type IS NULL")
                  end
                end
              end
            end
            
            #   specify "should read through the cache with find" do
            #     story = Story.create!(:title => "Story 1")
            #     character = story.characters.create(:name => "Sam")
            #     Character.connection.expects(:execute).never
            #
            #     story.characters.find(character.id).should == character
            #   end
            #
            #   specify "should read through the cache with find when given multiple ids" do
            #     story = Story.create!(:title => "Story 1")
            #     character1 = story.characters.create(:name => "Sam")
            #     character2 = story.characters.create(:name => "Nick")
            #     Character.connection.expects(:execute).never
            #
            #     story.characters.find(character1.id, character2.id).should == [character1, character2]
            #   end
          end
        end
        
        describe 'find(:all)' do
          describe 'find(:all, :conditions => {...})' do
            it 'does not use the database' do
              story1 = Story.create!(:title => title = "title")
              story2 = Story.create!(:title => title)
              mock(Story.connection).execute.never
              Story.find(:all, :conditions => { :title => story1.title }).should == [story1, story2]
            end
          end
          #   specify "should not use the cache when none of the indices match" do
          #     character = Character.create(:name => "Sam", :story_id => 1)
          #     Character.expects(:fetch_cache).never
          #     Character.find(:all).should == [character]
          #   end

          #   specify "cached attributes should support limits and offsets" do
          #     character1 = Character.create(:name => "Sam", :story_id => 1)
          #     character2 = Character.create(:name => "Sam", :story_id => 1)
          #     character3 = Character.create(:name => "Sam", :story_id => 1)
          #     Character.connection.expects(:execute).never
          #
          #     Character.find(:all, :conditions => { :name => character1.name, :story_id => character1.story_id }, :limit => 1).should == [character1]
          #     Character.find(:all, :conditions => { :name => character1.name, :story_id => character1.story_id }, :offset => 1).should == [character2, character3]
          #     Character.find(:all, :conditions => { :name => character1.name, :story_id => character1.story_id }, :limit => 1, :offset => 1).should == [character2]
          #   end
          
        end
        
        describe 'find([1, 2, ...], :conditions => ...)' do
          it "uses the database, not the cache" do
            story1 = Story.create!
            story2 = Story.create!
            mock(Story).fetch_cache.never
            Story.find([story1.id, story2.id], :conditions => "stories.id <= #{story2.id } AND type IS NULL")
          end
          
          #   specify "should support limits and offsets correctly when find is called with ids" do
          #     character1 = Character.create(:name => "Sam", :story_id => 1)
          #     character2 = Character.create(:name => "Sam", :story_id => 1)
          #     character3 = Character.create(:name => "Sam", :story_id => 1)
          #     Character.find([character1.id, character2.id, character3.id], :conditions => { :name => "Sam"}, :limit => 2).should == [character1, character2]
          #   end
          #
          #   specify "should support limits and offsets correctly when find is called with ONE id" do
          #     character = Character.create(:name => "Sam", :story_id => 1)
          #     lambda { Character.find([character.id], :conditions => { :name => "Sam"}, :limit => 0) }.should.raise(ActiveRecord::RecordNotFound)
          #   end
          # end
          
        end
        
        describe '#find_by_attr' do
          describe 'on indexed attributes' do
            describe 'find_by_id(id)' do
              it "does not use the database" do
                story = Story.create!
                mock(Story.connection).execute.never
                Story.find_by_id(story.id).should == story
              end
            end
            
            describe 'find_by_title(title)' do
              it "should use the cache with find_by" do
                story1 = Story.create!(:title => 'title1')
                story2 = Story.create!(:title => 'title2')
                mock(Story.connection).execute.never
                Story.find_by_title('title1').should == story1
              end              
            end
          end
          
          #   specify "should read through the cache with find_by_" do
          #     story = Story.create!(:title => "Story 1")
          #     character = story.characters.create(:name => "Sam")
          #     Character.connection.expects(:execute).never
          #     story.characters.find_by_id(character.id).should == character
          #   end
        end
      end
      
      describe 'when the cache is partially populated' do
        describe '#find' do
          it "works" do
            story1 = Story.create!(:title => title = 'once upon a time...')
            Story.cache_repository.flush_all
            story2 = Story.create!(:title => title)
            Story.find(:all, :conditions => { :title => story1.title }).should == [story1, story2]
          end
        end
      end
    end

    describe 'calculations' do
      #   specify "should get count from the cache" do
      #     stories = [Story.create!(:title => title = 'asdf'), Story.create!(:title => title)]
      #     Story.connection.expects(:execute).never
      #     Story.expects(:fetch_cache).with("title:#{title}").returns(stories.map(&:id))
      #     Story.expects(:fetch_cache).with(keys = stories.collect { |story| "id:#{story.id}" }).returns(Hash[*keys.zip(stories).flatten])
      #     Story.count(:all, :conditions => { :title => title }).should == stories.size
      #   end
      #
      #   specify "should not get count from the cache if column is specified" do
      #     stories = [Story.create!(:title => title = 'asdf'), Story.create!(:title => title)]
      #     Story.expects(:fetch_cache).never
      #     Story.count(:type, :conditions => { :title => title }).should == Story.find(:all, :conditions => "type IS NOT NULL").size
      #   end
      #
      #   specify "should generate the correct query when counts do not use the cache" do
      #     Story.destroy_all
      #     Story.create!(:title => title = "a title")
      #     Story.create!(:title => title)
      #     Story.create!(:title =>  "another title")
      #
      #     Story.expects(:fetch_cache).never
      #     Story.count(:all, :distinct => true, :select => 'title').should == 2
      #   end
      #
      #   specify "should support calculations without options on association proxies" do
      #     story = Story.create!(:title => "blah")
      #     story.characters.create!(:name => 'hi')
      #     story.characters.sum(:id)
      #   end
      # end
      
    end

  # context "STI" do
  #   specify "should be supported by finders" do
  #     story = Story.create!(:title => title = 'foo')
  #     feature = Feature.create!(:title => title)
  #     detail = Detail.create!(:title => title)
  #     Story.expects(:fetch_cache).once.with("title:#{title}").returns([story.id, feature.id, detail.id])
  #     stories = [story, feature, detail]
  #     Story.expects(:fetch_cache).once.with(keys = stories.collect { |s| "id:#{s.id}" }).returns(Hash[*keys.zip(stories).flatten])
  #     Story.find(:all, :conditions => { :title => title }).should == [story, feature, detail]
  #     Story.expects(:fetch_cache).never
  #     Feature.find(:all, :conditions => { :title => title }).should == [feature, detail]
  #     Detail.find(:all, :conditions => { :title => title }).should == [detail]
  #   end
  #
  #   specify "on write through should not pollute the base-class cache" do
  #     story = Story.create!(:title => title = 'foo')
  #     feature = Feature.create!(:title => title)
  #     Story.cache_repository.flush_all
  #     detail = Detail.create!(:title => title)
  #     Story.find(:all, :conditions => { :title => title }).should == [story, feature, detail]
  #   end
  #
  #   specify "should support find(id) for non-base-classes" do
  #     feature = Feature.create!(:title => 'title')
  #     Feature.find(feature.id).should == feature
  #   end
  # end
  end