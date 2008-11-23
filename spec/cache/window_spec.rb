require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe '' do

    describe "#find(:all, :conditions => ...)" do
    end

    describe "#find(:all, :conditions => ..., :limit => >100)" do
    end

    describe "#find(:all, :conditions => ..., :limit => <=100)" do
    end

    describe '#create!' do
      describe 'when you have > limit + buffer items' do
        it 'truncates when you have more than limit + buffer' do
        end
      end

      describe 'when you have < limit + buffer items' do
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