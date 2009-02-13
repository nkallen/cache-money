require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Marshal do
  describe '#load' do
    before do
      class Constant; end
      @reference_to_constant = Constant
      @object = @reference_to_constant.new
      @marshaled_object = Marshal.dump(@object)
    end

    describe 'when the constant is not yet loaded' do
      it 'loads the constant' do
        Object.send(:remove_const, :Constant)
        stub(Marshal).constantize(@reference_to_constant.name) { Object.send(:const_set, :Constant, @reference_to_constant) }
        Marshal.load(@marshaled_object).class.should == @object.class
      end
    end

    describe 'when the constant does not exist' do
      it 'raises a LoadError' do
        Object.send(:remove_const, :Constant)
        stub(Marshal).constantize { raise NameError }
        lambda { Marshal.load(@marshaled_object) }.should raise_error(NameError)
      end
    end

    describe 'when there are recursive constants to load' do
      it 'loads all constants recursively' do
        class Constant1; end
        class Constant2; end
        reference_to_constant1 = Constant1
        reference_to_constant2 = Constant2
        object = [reference_to_constant1.new, reference_to_constant2.new]
        marshaled_object = Marshal.dump(object)
        Object.send(:remove_const, :Constant1)
        Object.send(:remove_const, :Constant2)
        stub(Marshal).constantize(reference_to_constant1.name) { Object.send(:const_set, :Constant1, reference_to_constant1) }
        stub(Marshal).constantize(reference_to_constant2.name) { Object.send(:const_set, :Constant2, reference_to_constant2) }
        Marshal.load(marshaled_object).collect(&:class).should == object.collect(&:class)
      end
    end
  end
end
