require 'rubygems'
require 'bundler/setup'

require 'em-promise'


describe EventMachine::Defer do

	
	it "should fulfill the promise and execute all success callbacks in the registration order" do
		EventMachine.run {
			proc { |name|
				deferred = EM::Defer.new
				EM.defer { deferred.resolve("Hello #{name}") }
				deferred.promise.then(proc {|result|
					result += "?"
					result
				})
			}.call('Robin Hood').then(proc { |greeting|
				greeting.should == 'Hello Robin Hood?'
				EventMachine.stop
			}, proc { |reason|
				fail(reason)
				EventMachine.stop
			})
		}
	end


end
