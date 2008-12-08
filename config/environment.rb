require 'activerecord'

ActiveRecord::Base.establish_connection(
  :adapter => 'mysql',
  :socket => '/tmp/mysql.sock',
  :host => 'web030',
  :port => 3306,
  :username => 'root',
  :password => '',
  :encoding => 'UTF8',
  :host => 'localhost',
  :database => 'cash_test'
)