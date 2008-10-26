$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'cache/lock'
require 'cache/transactional'
require 'cache/buffered'