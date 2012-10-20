# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-promise/version"

Gem::Specification.new do |s|
  s.name        = "em-promise"
  s.version     = EventMachine::Defer::VERSION

  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stephen von Takach"]
  s.email       = ["steve@cotag.me"]
  s.homepage    = "https://github.com/cotag/em-promise"
  s.summary     = "EventMachine based, promise/deferred implementation"
  s.description = s.summary

  s.add_dependency "eventmachine", ">= 1.0.0.beta.4"
  s.add_development_dependency "rspec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
