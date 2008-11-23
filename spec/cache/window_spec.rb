# require File.join(File.dirname(__FILE__), '..', 'spec_helper')
#

# module Cache
#   describe Builder do
#     describe 'order' do
#       before do
#         Fable = Class.new(Story)
#         Fable.index do |index|
#           index.on :title, :order => :desc
#         end
#       end
#

#       describe 'various formats' do
#         describe "#find(:all, :conditions => ..., :order => 'id DESC')" do
#         end
#         describe "#find(:all, :conditions => ..., :order => 'table.id DESC')" do
#         end
#         describe "#find(:all, :conditions => ..., :order => '`table`.id DESC')" do
#         end
#         describe "#find(:all, :conditions => ..., :order => '`table`.`id` DESC')" do
#         end
#         describe "#find(:all, :conditions => ..., :order => '`table`.`id` desc')" do
#         end
#         describe "#find(:all, :conditions => ..." do
#         end
#       end
#

#       describe '#create!' do
#         describe 'when the cache is populated' do
#           describe 'when desc' do
#             it 'puts it on the left' do
#             end
#           end
#

#           describe 'when asc' do
#             it 'puts it on the right' do
#             end
#           end
#         end
#

#         describe 'when the cache is not populated' do
#           it 'loads the results from the database in the proper order' do
#           end
#         end
#       end
#     end
#

#     describe '' do
#       before do
#         FairyTale = Class.new(Story)
#         FairyTale.index do |index|
#           index.on :title, :limit => 100, :buffer => 100
#         end
#

#         describe "#find(:all, :conditions => ...)" do
#         end
#

#         describe "#find(:all, :conditions => ..., :limit => >100)" do
#         end
#

#         describe "#find(:all, :conditions => ..., :limit => <=100)" do
#         end
#

#         describe '#create!' do
#           describe 'when you have > limit + buffer items' do
#             it 'truncates when you have more than limit + buffer' do
#             end
#           end
#

#           describe 'when you have < limit + buffer items' do
#           end
#         end
#

#         describe '#destroy!' do
#           describe 'when you have <= limit of items' do
#             describe 'when the count is <= limit of items' do
#             end
#

#             describe 'when the count > limit of items' do
#             end
#           end
#

#           describe 'when you have > limit of items' do
#           end
#         end
#

#       end
#     end
#   end
# end