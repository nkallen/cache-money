require 'activerecord'

ActiveRecord::Base.establish_connection(
  :adapter => 'mysql',
  :port => 3306,
  :username => 'root',
  :password => 'password',
  :encoding => 'UTF8',
  :host => 'localhost',
  :database => 'cache_test'
)
