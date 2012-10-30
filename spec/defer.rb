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
			
			it "should allow registration of a success callback without an errback and resolve" do
				EventMachine.run {
					@promise.then(proc {|result|
						@log << result
					})

					@deferred.resolve(:foo)
					
					EM.next_tick do
						@log.should == [:foo]
						EM.stop
					end
				}
			end
			
			
			it "should allow registration of a success callback without an errback and reject" do
				EventMachine.run {
					@promise.then(proc {|result|
						@log << result
					})

					@deferred.reject(:foo)
					
					EM.next_tick do
						@log.should == []
						EM.stop
					end
				}
			end
			
			
			it "should allow registration of an errback without a success callback and reject" do
				EventMachine.run {
					@promise.then(nil, proc {|reason|
						@log << reason
					})

					@deferred.reject(:foo)
					
					EM.next_tick do
						@log.should == [:foo]
						EM.stop
					end
				}
			end
			
			
			it "should allow registration of an errback without a success callback and resolve" do
				EventMachine.run {
					@promise.then(nil, proc {|reason|
						@log << reason
					})

					@deferred.resolve(:foo)
					
					EM.next_tick do
						@log.should == []
						EM.stop
					end
				}
			end
			
			
			it "should resolve all callbacks with the original value" do
				EventMachine.run {
					@promise.then(proc {|result|
						@log << result
						:alt1
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						'ERROR'
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						EM::Defer.reject('some reason')
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						:alt2
					}, @default_fail)
					
					@deferred.resolve(:foo)
					
					EM.next_tick do
						@log.should == [:foo, :foo, :foo, :foo]
						EM.stop
					end
				}
			end
			
			
			it "should reject all callbacks with the original reason" do
				EventMachine.run {
					@promise.then(@default_fail, proc {|result|
						@log << result
						:alt1
					})
					@promise.then(@default_fail, proc {|result|
						@log << result
						'ERROR'
					})
					@promise.then(@default_fail, proc {|result|
						@log << result
						EM::Defer.reject('some reason')
					})
					@promise.then(@default_fail, proc {|result|
						@log << result
						:alt2
					})
					
					@deferred.reject(:foo)
					
					EM.next_tick do
						@log.should == [:foo, :foo, :foo, :foo]
						EM.stop
					end
				}
			end
			
			
			it "should propagate resolution and rejection between dependent promises" do
				EventMachine.run {
					@promise.then(proc {|result|
						@log << result
						:bar
					}, @default_fail).then(proc {|result|
						@log << result
						raise 'baz'
					}, @default_fail).then(@default_fail, proc {|result|
						@log << result.message
						raise 'bob'
					}).then(@default_fail, proc {|result|
						@log << result.message
						:done
					}).then(proc {|result|
						@log << result
					}, @default_fail)
					
					@deferred.resolve(:foo)
					
					EM.next_tick do
						EM.next_tick do
							EM.next_tick do
								EM.next_tick do
									EM.next_tick do
										@log.should == [:foo, :bar, 'baz', 'bob', :done]
										EM.stop
									end
								end
							end
						end
					end
				}
			end
			
			
			it "should call error callback in the next turn even if promise is already rejected" do
				EventMachine.run {
					@deferred.reject(:foo)
					
					@promise.then(nil, proc {|reason|
						@log << reason
					})
					
					EM.next_tick do
						@log.should == [:foo]
						EM.stop
					end
				}
			end
			
			
		end
		
	end
	
	
	
	describe 'reject' do
		
		it "should package a string into a rejected promise" do
			EventMachine.run {
				rejectedPromise = EM::Defer.reject('not gonna happen')
				
				@promise.then(nil, proc {|reason|
					@log << reason
				})
				
				@deferred.resolve(rejectedPromise)
				
				EM.next_tick do
					@log.should == ['not gonna happen']
					EM.stop
				end
			}
		end
		
		
		it "should return a promise that forwards callbacks if the callbacks are missing" do
			EventMachine.run {
				rejectedPromise = EM::Defer.reject('not gonna happen')
				
				@promise.then(nil, proc {|reason|
					@log << reason
				})
				
				@deferred.resolve(rejectedPromise.then())
				
				EM.next_tick do
					EM.next_tick do
						@log.should == ['not gonna happen']
						EM.stop
					end
				end
			}
		end
		
	end
	
	
	
	describe 'all' do
		
		it "should resolve all of nothing" do
			EventMachine.run {
				EM::Defer.all().then(proc {|result|
					@log << result
				}, @default_fail)
				
				EM.next_tick do
					@log.should == [[]]
					EM.stop
				end
			}
		end
		
		it "should take an array of promises and return a promise for an array of results" do
			EventMachine.run {
				deferred1 = EM::Defer.new
				deferred2 = EM::Defer.new
				
				EM::Defer.all(@promise, deferred1.promise, deferred2.promise).then(proc {|result|
					result.should == [:foo, :bar, :baz]
					EM.stop
				}, @default_fail)
				
				EM.defer { @deferred.resolve(:foo) }
				EM.defer { deferred2.resolve(:baz) }
				EM.defer { deferred1.resolve(:bar) }
			}
		end
		
		
		it "should reject the derived promise if at least one of the promises in the array is rejected" do
			EventMachine.run {
				deferred1 = EM::Defer.new
				deferred2 = EM::Defer.new
				
				EM::Defer.all(@promise, deferred1.promise, deferred2.promise).then(@default_fail, proc {|reason|
					reason.should == :baz
					EM.stop
				})
				
				EM.defer { @deferred.resolve(:foo) }
				EM.defer { deferred2.reject(:baz) }
			}
		end
		
	end
	


end
