Gem::Specification.new do |s|
  s.name     = "cache"
  s.version  = "0.1.0"
  s.date     = "2008-11-24"
  s.summary  = "Write-through Cacheing for ActiveRecord"
  s.email    = "nick@twitter.com"
  s.homepage = "http://github.com/nkallen/cash"
  s.description = "Cache utilities."
  s.has_rdoc = false
  s.authors  = ["Nick Kallen"]
  s.files    = [
    "README",
    "TODO",
    "UNSUPPORTED_FEATURES",
    "lib/cache/accessor.rb",
    "lib/cache/buffered.rb",
    "lib/cache/config.rb",
    "lib/cache/finders.rb",
    "lib/cache/index.rb",
    "lib/cache/local.rb",
    "lib/cache/lock.rb",
    "lib/cache/mock.rb",
    "lib/cache/query/abstract.rb",
    "lib/cache/query/calculation.rb",
    "lib/cache/query/primary_key.rb",
    "lib/cache/query/select.rb",
    "lib/cache/transactional.rb",
    "lib/cache/util/array.rb",
    "lib/cache/write_through.rb",
    "lib/cache.rb"
  ]
  s.test_files = [
    "config/environment.rb",
    "config/memcache.yml",
    "db/schema.rb",
    "spec/cache/accessor_spec.rb",
    "spec/cache/active_record_spec.rb",
    "spec/cache/calculations_spec.rb",
    "spec/cache/finders_spec.rb",
    "spec/cache/lock_spec.rb",
    "spec/cache/order_spec.rb",
    "spec/cache/transactional_spec.rb",
    "spec/cache/window_spec.rb",
    "spec/cache/write_through_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.add_dependency("activerecord", ["> 2.2.0"])
  s.add_dependency("activesupport", ["> 2.2.0"])
end