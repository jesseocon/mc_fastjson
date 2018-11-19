$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "mc_fastjson/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mc_fastjson"
  s.version     = McFastjson::VERSION
  s.authors     = ["Jesse Ocon"]
  s.email       = ["jesse@masterclass.com"]
  s.homepage    = "https://masterclass.com"
  s.summary     = "Companion to the awesome Netflix/FastJson object serializer"
  s.description = "Adds some basic items needed to go from a serializers to a plug and play API framework"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.2.1"
  s.add_dependency "fast_jsonapi"
  s.add_dependency 'pundit'

  s.add_development_dependency "rspec-rails"

  s.add_development_dependency "sqlite3"
end
