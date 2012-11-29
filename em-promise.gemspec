# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-promise/version"

Gem::Specification.new do |s|
  s.name        = "em-promise"
  s.version     = EventMachine::Q::VERSION

  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stephen von Takach"]
  s.email       = ["steve@cotag.me"]
  s.homepage    = "https://github.com/cotag/em-promise"
  s.summary     = "EventMachine based, promise/deferred implementation"
  s.description = s.summary

  s.add_dependency "eventmachine", ">= 1.0.0.beta.4"
  s.add_development_dependency "rspec"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.textile"]
  s.test_files = Dir["spec/**/*"]
  s.require_paths = ["lib"]
end
