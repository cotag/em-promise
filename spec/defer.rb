require 'rubygems'
require 'bundler/setup'

require 'em-promise'


describe EventMachine::Defer do
	
	before :each do
		@deferred = EM::Defer.new
		@promise = @deferred.promise
		@log = []
		@default_fail = proc { |reason|
			fail(reason)
			EM.stop
		}
	end
	
	
	describe 'resolve' do
		
		
		it "should call the callback in the next turn" do
			deferred2 = EM::Defer.new
			EventMachine.run {
				@promise.then(proc {|result|
					@log << result
				}, @default_fail)
				
				@deferred.resolve(:foo)
				
				EM.next_tick do
					@log.should == [:foo]
					EM.stop
				end
			}
		end
		
		
		it "should fulfill success callbacks in the registration order" do
			EventMachine.run {
				@promise.then(proc {|result|
					@log << :first
				}, @default_fail)
				
				@promise.then(proc {|result|
					@log << :second
				}, @default_fail)
				
				@deferred.resolve(:foo)
				
				EM.next_tick do
					@log.should == [:first, :second]
					EM.stop
				end
			}
		end
		
		
		it "should do nothing if a promise was previously resolved" do
			EventMachine.run {
				@promise.then(proc {|result|
					@log << result
					@log.should == [:foo]
					@deferred.resolve(:bar)
				}, @default_fail)
				
				@deferred.resolve(:foo)
				@deferred.reject(:baz)
				
				#
				# 4 ticks should detect any errors
				#
				EM.next_tick do
					EM.next_tick do
						EM.next_tick do
							EM.next_tick do
								@log.should == [:foo]
								EM.stop
							end
						end
					end
				end
			}
		end
		
		
		it "should allow deferred resolution with a new promise" do
			deferred2 = EM::Defer.new
			EventMachine.run {
				@promise.then(proc {|result|
					result.should == :foo
					EM.stop
				}, @default_fail)
				
				@deferred.resolve(deferred2.promise)
				deferred2.resolve(:foo)
			}
		end
		
		
		it "should not break if a callbacks registers another callback" do
			EventMachine.run {
				@promise.then(proc {|result|
					@log << :outer
					@promise.then(proc {|result|
						@log << :inner
					}, @default_fail)
				}, @default_fail)
				
				@deferred.resolve(:foo)
				
				EM.next_tick do
					EM.next_tick do
						@log.should == [:outer, :inner]
						EM.stop
					end
				end
			}
		end
		
		
		
		it "can modify the result of a promise before returning" do
			EventMachine.run {
				proc { |name|
					EM.defer { @deferred.resolve("Hello #{name}") }
					@promise.then(proc {|result|
						result.should == 'Hello Robin Hood'
						result += "?"
						result
					})
				}.call('Robin Hood').then(proc { |greeting|
					greeting.should == 'Hello Robin Hood?'
					EM.stop
				}, @default_fail)
			}
		end
	
	end
	
	
	describe 'reject' do
	
		it "should reject the promise and execute all error callbacks" do
			EventMachine.run {
				@promise.then(@default_fail, proc {|result|
					@log << :first
				})
				@promise.then(@default_fail, proc {|result|
					@log << :second
				})
				
				@deferred.reject(:foo)
				
				EM.next_tick do
					@log.should == [:first, :second]
					EM.stop
				end
			}
		end
		
		
		it "should do nothing if a promise was previously rejected" do
			EventMachine.run {
				@promise.then(@default_fail, proc {|result|
					@log << result
					@log.should == [:baz]
					@deferred.resolve(:bar)
				})
				
				@deferred.reject(:baz)
				@deferred.resolve(:foo)
				
				#
				# 4 ticks should detect any errors
				#
				EM.next_tick do
					EM.next_tick do
						EM.next_tick do
							EM.next_tick do
								@log.should == [:baz]
								EM.stop
							end
						end
					end
				end
			}
		end
		
		
		it "should not defer rejection with a new promise" do
			deferred2 = EM::Defer.new
			EventMachine.run {
				@promise.then(@default_fail, @default_fail)
				begin
					@deferred.reject(deferred2.promise)
				rescue => e
					e.is_a?(ArgumentError).should == true
					EM.stop
				end
			}
		end
		
	end
	
	
	describe EventMachine::Defer::Promise do
		
		describe 'then' do
			
			it "should not defer rejection with a new promise" do
				true.should == true	# TODO!! ;)
			end
			
		end
		
	end
	


end
