require File.join(File.dirname(__FILE__), '..', 'spec_helper')

module Cache
  describe Builder do
    describe 'order' do
      before do
        Fable = Class.new(Story)
        Fable.index do |index|
          index.on :title, :order => :desc, :limit => 100, :buffer => 100
        end
      end

      describe "#find(:all, :conditions => ..., :order => 'id DESC')" do
      end
      describe "#find(:all, :conditions => ..., :order => 'table.id DESC')" do
      end
      describe "#find(:all, :conditions => ..., :order => '`table`.id DESC')" do
      end
      describe "#find(:all, :conditions => ..., :order => '`table`.`id` DESC')" do
      end
      describe "#find(:all, :conditions => ..., :order => '`table`.`id` desc')" do
      end
      describe "#find(:all, :conditions => ..." do
      end

      describe '#create!' do
      end
    end

    describe '' do
      before do
        FairyTale = Class.new(Story)
        FairyTale.index do |index|
          index.on :title, :limit => 100, :buffer => 100
        end
      end
    end
  end
end