Gem::Specification.new do |s|
  s.name     = "cache-money"
  s.version  = "0.2.5"
  s.date     = "2008-11-24"
  s.summary  = "Write-through and Read-through Cacheing for ActiveRecord"
  s.email    = "nick@twitter.com"
  s.homepage = "http://github.com/nkallen/cache-money"
  s.description = "Cache utilities."
  s.has_rdoc = false
  s.authors  = ["Nick Kallen"]
  s.files    = [
    "README",
    "TODO",
    "UNSUPPORTED_FEATURES",
    "lib/cash/accessor.rb",
    "lib/cash/buffered.rb",
    "lib/cash/config.rb",
    "lib/cash/finders.rb",
    "lib/cash/index.rb",
    "lib/cash/local.rb",
    "lib/cash/lock.rb",
    "lib/cash/mock.rb",
    "lib/cash/query/abstract.rb",
    "lib/cash/query/calculation.rb",
    "lib/cash/query/primary_key.rb",
    "lib/cash/query/select.rb",
    "lib/cash/request.rb",
    "lib/cash/transactional.rb",
    "lib/cash/util/array.rb",
    "lib/cash/write_through.rb",
    "lib/cache_money.rb"
  ]
  s.test_files = [
    "config/environment.rb",
    "config/memcache.yml",
    "db/schema.rb",
    "spec/cash/accessor_spec.rb",
    "spec/cash/active_record_spec.rb",
    "spec/cash/calculations_spec.rb",
    "spec/cash/finders_spec.rb",
    "spec/cash/lock_spec.rb",
    "spec/cash/order_spec.rb",
    "spec/cash/transactional_spec.rb",
    "spec/cash/window_spec.rb",
    "spec/cash/write_through_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.add_dependency("activerecord", [">= 2.2.0"])
  s.add_dependency("activesupport", [">= 2.2.0"])
  s.add_dependency("memcache-client", [">= 1.5.0 "])
end
