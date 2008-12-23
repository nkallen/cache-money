require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cash
  describe Finders do
    describe 'when the cache is populated' do
      describe "#find" do
        describe '#find(id...)' do
          describe '#find(id)' do
            it "returns an active record" do
              story = Story.create!(:title => 'a story')
              Story.find(story.id).should == story
            end
          end

          describe 'when the object is destroyed' do
            describe '#find(id)' do
              it "raises an error" do
                story = Story.create!(:title => "I am delicious")
                story.destroy
                lambda { Story.find(story.id) }.should raise_error(ActiveRecord::RecordNotFound)
              end
            end
          end

          describe '#find(id1, id2, ...)' do
            it "returns an array" do
              story1, story2 = Story.create!, Story.create!
              Story.find(story1.id, story2.id).should == [story1, story2]
            end

            describe "#find(id, nil)" do
              it "ignores the nils" do
                story = Story.create!
                Story.find(story.id, nil).should == story
              end
            end
          end

          describe 'when given nonexistent ids' do
            describe 'when given one nonexistent id' do
              it 'raises an error' do
                lambda { Story.find(1) }.should raise_error(ActiveRecord::RecordNotFound)
              end
            end

            describe 'when given multiple nonexistent ids' do
               it "raises an error" do
                lambda { Story.find(1, 2, 3) }.should raise_error(ActiveRecord::RecordNotFound)
              end
            end


            describe '#find(nil)' do
              it 'raises an error' do
                lambda { Story.find(nil) }.should raise_error(ActiveRecord::RecordNotFound)
              end
            end
          end
        end

        describe '#find(object)' do
          it "coerces arguments to integers" do
            story = Story.create!
            Story.find(story.id.to_s).should == story
          end
        end

        describe '#find([...])' do
          describe 'when given an array with valid ids' do
            it "#finds the object with that id" do
              story = Story.create!
              Story.find([story.id]).should == [story]
            end
          end

          describe '#find([])' do
            it 'returns the empty array' do
              Story.find([]).should == []
            end
          end

          describe 'when given nonexistent ids' do
            it 'raises an error' do
              lambda { Story.find([1, 2, 3]) }.should raise_error(ActiveRecord::RecordNotFound)
            end
          end

          describe 'when given limits and offsets' do
            describe '#find([1, 2, ...], :limit => ..., :offset => ...)' do
              it "returns the correct slice of objects" do
                character1 = Character.create!(:name => "Sam", :story_id => 1)
                character2 = Character.create!(:name => "Sam", :story_id => 1)
                character3 = Character.create!(:name => "Sam", :story_id => 1)
                Character.find(
                  [character1.id, character2.id, character3.id],
                  :conditions => { :name => "Sam", :story_id => 1 }, :limit => 2
                ).should == [character1, character2]
              end
            end

            describe '#find([1], :limit => 0)' do
              it "raises an error" do
                character = Character.create!(:name => "Sam", :story_id => 1)
                lambda do
                  Character.find([character.id], :conditions => { :name => "Sam", :story_id => 1 }, :limit => 0)
                end.should raise_error(ActiveRecord::RecordNotFound)
              end
            end
          end
        end

        describe '#find(:first, ..., :offset => ...)' do
          it "#finds the object in the correct order" do
            story1 = Story.create!(:title => 'title1')
            story2 = Story.create!(:title => story1.title)
            Story.find(:first, :conditions => { :title => story1.title }, :offset => 1).should == story2
          end
        end

        describe '#find(:first, :conditions => [])' do
          it 'works' do
            story = Story.create!
            Story.find(:first, :conditions => []).should == story
          end
        end
        
        describe "#find(:first, :conditions => '...')" do
          it "uses the active record instance to typecast values extracted from the conditions" do
            story1 = Story.create! :title => 'a story', :published => true
            story2 = Story.create! :title => 'another story', :published => false
            Story.get('published/false').should == [story2.id]
            Story.find(:first, :conditions => 'published = 0').should == story2
          end
        end
      end

      describe '#find_by_attr' do
        describe '#find_by_attr(nil)' do
          it 'returns nil' do
            Story.find_by_id(nil).should == nil
          end
        end

        describe 'when given non-existent ids' do
          it 'returns nil' do
            Story.find_by_id(-1).should == nil
          end
        end
      end

      describe '#find_all_by_attr' do
        describe 'when given non-existent ids' do
          it "does not raise an error" do
            lambda { Story.find_all_by_id([-1, -2, -3]) }.should_not raise_error
          end
        end
      end
    end

    describe 'when the cache is partially populated' do
      describe '#find(:all, :conditions => ...)' do
        it "returns the correct records" do
          story1 = Story.create!(:title => title = 'once upon a time...')
          $memcache.flush_all
          story2 = Story.create!(:title => title)
          Story.find(:all, :conditions => { :title => story1.title }).should == [story1, story2]
        end
      end

      describe '#find(id1, id2, ...)' do
        it "returns the correct records" do
          story1 = Story.create!(:title => 'story 1')
          $memcache.flush_all
          story2 = Story.create!(:title => 'story 2')
          Story.find(story1.id, story2.id).should == [story1, story2]
        end
      end
    end

    describe 'when the cache is not populated' do
      describe '#find(id)' do
        it "returns the correct records" do
          story = Story.create!(:title => 'a story')
          $memcache.flush_all
          Story.find(story.id).should == story
        end
      end

      describe '#find(id1, id2, ...)' do
        it "handles finds with multiple ids correctly" do
          story1 = Story.create!
          story2 = Story.create!
          $memcache.flush_all
          Story.find(story1.id, story2.id).should == [story1, story2]
        end
      end
    end
  end
end
